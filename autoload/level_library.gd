extends Node

# Non-calibrate songs live under game_levels/<difficulty>/ (easy/medium/hard).
# The res://levels/ flat directory is kept as a legacy fallback.
const LEVELS_DIR := "res://levels"
const GAME_LEVELS_DIR := "res://game_levels"

# Difficulty folders inside game_levels/ (case-insensitive match at scan time).
const DIFFICULTY_DIRS: Array[String] = ["easy", "medium", "hard"]

# All calibrate songs are under res://game_levels/calibrate/.
# The folder layout is:
#   game_levels/calibrate/Level_N/no_music/<chart>.json   (no_music)
#   game_levels/calibrate/LEVELN_MUSIC_*.json             (music, flat)
const CALIBRATE_DIR := "res://game_levels/calibrate"

var levels: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> void:
	levels.clear()
	_scan_difficulty_dirs()
	_scan_calibrate()
	_scan_legacy_levels()

# ── Non-calibrate songs: game_levels/easy|medium|hard/ ──────────────────────

# Each difficulty folder is a flat list of JSON files. The difficulty is taken
# from the JSON's own "difficulty" field if present; otherwise it is inferred
# from the folder name (capitalised: easy→EASY, medium→MEDIUM, hard→HARD).
func _scan_difficulty_dirs() -> void:
	for diff in DIFFICULTY_DIRS:
		var dir_path := GAME_LEVELS_DIR + "/" + diff
		_ensure_dir(dir_path)
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		var folder_difficulty := diff.to_upper()   # EASY / MEDIUM / HARD
		for file in dir.get_files():
			if not file.ends_with(".json"):
				continue
			var lvl := _load_json(dir_path + "/" + file)
			if lvl.is_empty():
				continue
			# Honour an explicit difficulty in the JSON; fall back to folder name.
			if lvl.get("difficulty", "") == "":
				lvl["difficulty"] = folder_difficulty
			var id: String = str(lvl.get("id", file.get_basename()))
			levels[id] = _normalize(lvl)

# ── Legacy fallback: res://levels/ flat directory ───────────────────────────
# Any non-calibrate JSON still sitting in the old flat levels/ folder is loaded
# so nothing breaks while the migration is in progress.

func _scan_legacy_levels() -> void:
	var dir := DirAccess.open(LEVELS_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var lvl := _load_json(LEVELS_DIR + "/" + file)
		if lvl.is_empty():
			continue
		if lvl.get("difficulty", "") == "CALIBRATE":
			continue
		var id: String = str(lvl.get("id", file.get_basename()))
		# Don't overwrite a level already loaded from game_levels/
		if not levels.has(id):
			levels[id] = _normalize(lvl)

# ── Calibrate songs (new game_levels/calibrate/ tree) ───────────────────────

# Walk the calibrate directory tree.  Two layouts are recognised:
#
#   LEVELN_MUSIC_*.json          → music variant, directly under CALIBRATE_DIR
#   Level_N/no_music/*.json      → no_music variant, inside a sub-subdirectory
#
# The folder name encodes the level number (Level_1 / Level_2 / Level_3 or
# the prefix of LEVEL1_MUSIC_… etc.) and the mode (music / no_music).
func _scan_calibrate() -> void:
	_ensure_dir(CALIBRATE_DIR)
	var root := DirAccess.open(CALIBRATE_DIR)
	if root == null:
		return

	# Flat files directly in CALIBRATE_DIR → music variants
	for file in root.get_files():
		if not file.ends_with(".json"):
			continue
		var lvl := _load_json(CALIBRATE_DIR + "/" + file)
		if lvl.is_empty():
			continue
		var level_num := _level_num_from_music_filename(file)
		var id: String = str(lvl.get("id", file.get_basename()))
		levels[id] = _normalize_calibrate(lvl, level_num, "music")

	# Sub-directories → Level_1, Level_2, Level_3
	for sub_dir_name in root.get_directories():
		var level_num := _level_num_from_dirname(sub_dir_name)
		if level_num < 1:
			continue
		var level_path := CALIBRATE_DIR + "/" + sub_dir_name

		# no_music sub-subdirectory
		var no_music_path := level_path + "/no_music"
		var no_music_dir := DirAccess.open(no_music_path)
		if no_music_dir:
			for file in no_music_dir.get_files():
				if not file.ends_with(".json"):
					continue
				var lvl := _load_json(no_music_path + "/" + file)
				if lvl.is_empty():
					continue
				var id: String = str(lvl.get("id", file.get_basename()))
				levels[id] = _normalize_calibrate(lvl, level_num, "no_music")

# Extract level number (1/2/3) from a directory name like "Level_1", "Level_2".
func _level_num_from_dirname(name: String) -> int:
	# Accepts "Level_1", "level_1", "Level1", etc.
	var lower := name.to_lower()
	for n in [1, 2, 3]:
		if lower.ends_with("_" + str(n)) or lower.ends_with(str(n)):
			return n
	return -1

# Extract level number from a flat music filename like "LEVEL1_MUSIC_LEFT.json"
# or "LEVEL2_MUSIC_DOWN.json".
func _level_num_from_music_filename(filename: String) -> int:
	var upper := filename.to_upper()
	if upper.begins_with("LEVEL1"):
		return 1
	if upper.begins_with("LEVEL2"):
		return 2
	if upper.begins_with("LEVEL3"):
		return 3
	return -1

# ── Public API ───────────────────────────────────────────────────────────────

func get_all() -> Dictionary:
	return levels

func get_level(id: String) -> Dictionary:
	if levels.has(id):
		return levels[id]
	if levels.is_empty():
		return {}
	return levels[levels.keys()[0]]

# Writes a level to the appropriate game_levels/<difficulty>/ folder.
# EASY/MEDIUM/HARD → game_levels/<difficulty>/  (created if missing)
# Anything else    → res://levels/ (legacy fallback, e.g. CALIBRATE charts)
# Returns the on-disk path, or "" on failure.
func save_level(id: String, data: Dictionary) -> String:
	var diff: String = str(data.get("difficulty", "")).to_lower()
	var target_dir: String
	if diff in DIFFICULTY_DIRS:
		target_dir = GAME_LEVELS_DIR + "/" + diff
	else:
		target_dir = LEVELS_DIR
	_ensure_dir(target_dir)
	var path := target_dir + "/" + id + ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	reload()
	return ProjectSettings.globalize_path(path)

# ── Normalisation ────────────────────────────────────────────────────────────

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
		"listen_windows": _norm_windows(lvl.get("listen_windows", [])),
		# These are not present on non-calibrate levels; kept for schema consistency.
		"calibrate_level": -1,
		"calibrate_mode": "",
	}

func _normalize_calibrate(lvl: Dictionary, level_num: int, mode: String) -> Dictionary:
	var fk = lvl.get("fk_times", [[], [], [], []])
	while fk.size() < 4:
		fk.append([])
	return {
		"title": str(lvl.get("title", "Untitled")),
		"zone": str(lvl.get("zone", "NORMAL")),
		"difficulty": "CALIBRATE",
		"music": str(lvl.get("music", "")),
		"fk_times": fk,
		"listen_windows": _norm_windows(lvl.get("listen_windows", [])),
		"calibrate_level": level_num,
		"calibrate_mode": mode,
	}

# ── Helpers ──────────────────────────────────────────────────────────────────

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

func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

