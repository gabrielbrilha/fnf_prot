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
	}

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
