extends Node

const LEVELS_DIR := "res://levels"

var levels: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> void:
	levels.clear()
	# created levels
	_ensure_dir()
	var dir := DirAccess.open(LEVELS_DIR)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".json"):
				var lvl := _load_json(LEVELS_DIR + "/" + file)
				if not lvl.is_empty():
					var id: String = str(lvl.get("id", file.get_basename()))
					levels[id] = _normalize(lvl)

func get_all() -> Dictionary:
	return levels

func get_level(id: String) -> Dictionary:
	if levels.has(id):
		return levels[id];
	if levels.is_empty():
		return {}
	return levels[levels.keys()[0]]

# Writes a level to user://levels/<id>.json and refreshes the catalog.
# Returns the on-disk path, or "" on failure.
func save_level(id: String, data: Dictionary) -> String:
	_ensure_dir()
	var path := LEVELS_DIR + "/" + id + ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	reload()
	return ProjectSettings.globalize_path(path)

func _normalize(lvl: Dictionary) -> Dictionary:
	var fk = lvl.get("fk_times", [[], [], [], []])
	while fk.size() < 4:
		fk.append([])
	return {
		"title": str(lvl.get("title", "Untitled")),
		"zone": str(lvl.get("zone", "NORMAL")),
		"difficulty": str(lvl.get("difficulty", "")),
		"music": str(lvl.get("music", "")),
		"fk_times": fk,
		# [[start, end], ...] song-time spans that show a LISTEN screen
		"listen_windows": _norm_windows(lvl.get("listen_windows", [])),
		# For CALIBRATE levels: the single lane this chart plays on
		# (0=Left, 1=Down, 2=Up, 3=Right). Explicit field wins; otherwise it's
		# inferred from the only non-empty lane. -1 when it can't be determined.
		"calibrate_direction": _calibrate_direction(lvl, fk),
	}

# Lane a calibrate chart plays on: the stored field if valid, else inferred from
# fk_times when exactly one lane has notes.
func _calibrate_direction(lvl: Dictionary, fk: Array) -> int:
	var stored := int(lvl.get("calibrate_direction", -1))
	if stored >= 0 and stored <= 3:
		return stored
	var only := -1
	for lane in 4:
		if lane < fk.size() and fk[lane].size() > 0:
			if only >= 0:
				return -1   # notes on more than one lane -> ambiguous
			only = lane
	return only

# Keep only valid [start, end] pairs (end > start), as floats.
func _norm_windows(raw) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for w in raw:
		if typeof(w) == TYPE_ARRAY and w.size() >= 2:
			var s := float(w[0])
			var e := float(w[1])
			if e > s:
				out.append([s, e])
	return out

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(LEVELS_DIR):
		DirAccess.make_dir_recursive_absolute(LEVELS_DIR)

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
