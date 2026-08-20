extends Control

# End-of-song results screen. Reads the play stats gathered in GameState during
# the song, shows the breakdown (using the same font and colours as the in-game
# judgment popups), and writes a log file to the user's system. Built entirely
# in code, like pause_menu.gd, so the scene file stays a one-liner.

const GAME_LEVEL_SCENE: String = "res://levels/game_level.tscn"
const MODE_SELECT_SCENE: String = "res://levels/mode_select.tscn"
const HUD_FONT := preload("res://art/BubbleBoomRegular-e96nn.ttf")
const LOG_DIR: String = "user://logs"

# same colours as the in-game judgment popups (score_press_text.gd)
const JUDGMENT_COLORS := {
	"PERFECT": Color("faab00"),
	"GREAT": Color("b4cb09"),
	"GOOD": Color("73da41"),
	"OK": Color("6cd695"),
	"MISS": Color("c6bd9a"),
}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_write_log()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("12121a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var level := LevelLibrary.get_level(GameState.selected_song_id)
	var song_title: String = level.get("title", GameState.selected_song_id)

	_add_label(vbox, "Results", 56, Color.WHITE)
	_add_label(vbox, song_title, 30, Color("d7d7e2"))
	_add_label(vbox, _difficulty_text(), 18, Color("9a9aa8"))

	_add_spacer(vbox, 10)

	# accuracy, large and bright
	_add_label(vbox, "Accuracy  %.1f%%" % GameState.stat_accuracy(), 44, Color.WHITE)

	# notes hit in time vs. the total that should have been hit
	_add_label(vbox,
		"Notes hit  %d / %d" % [GameState.stat_hits(), GameState.stat_total_notes],
		24, Color("d7d7e2"))

	_add_spacer(vbox, 10)

	# per-judgment breakdown, coloured like the in-game popups
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	_add_stat_row(grid, "PERFECT", GameState.stat_perfect)
	_add_stat_row(grid, "GREAT", GameState.stat_great)
	_add_stat_row(grid, "GOOD", GameState.stat_good)
	_add_stat_row(grid, "OK", GameState.stat_ok)
	_add_stat_row(grid, "MISS", GameState.stat_misses())

	_add_spacer(vbox, 16)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	var restart := Button.new()
	restart.text = "Restart"
	restart.custom_minimum_size = Vector2(180, 48)
	restart.add_theme_font_override("font", HUD_FONT)
	restart.add_theme_font_size_override("font_size", 24)
	restart.pressed.connect(_on_restart_pressed)
	row.add_child(restart)

	var menu := Button.new()
	menu.text = "Go to Menu"
	menu.custom_minimum_size = Vector2(180, 48)
	menu.add_theme_font_override("font", HUD_FONT)
	menu.add_theme_font_size_override("font_size", 24)
	menu.pressed.connect(_on_menu_pressed)
	row.add_child(menu)

func _add_label(parent: Node, text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", HUD_FONT)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	return lbl

func _add_spacer(parent: Node, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)

# One breakdown line: coloured judgment name on the left, count on the right.
func _add_stat_row(grid: GridContainer, judgment: String, count: int) -> void:
	var color: Color = JUDGMENT_COLORS[judgment]

	var name_lbl := Label.new()
	name_lbl.text = judgment
	name_lbl.add_theme_font_override("font", HUD_FONT)
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", color)
	grid.add_child(name_lbl)

	var count_lbl := Label.new()
	count_lbl.text = str(count)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.add_theme_font_override("font", HUD_FONT)
	count_lbl.add_theme_font_size_override("font_size", 26)
	count_lbl.add_theme_color_override("font_color", color)
	grid.add_child(count_lbl)

func _difficulty_text() -> String:
	return GameState.selected_difficulty if GameState.has_difficulty() else "-"

# Writes a per-play log to the user's data folder (user://logs). Includes the
# song, the date/time it was played, and every figure shown on this screen.
func _write_log() -> void:
	DirAccess.make_dir_recursive_absolute(LOG_DIR)

	var now := Time.get_datetime_dict_from_system()
	var stamp := "%04d-%02d-%02d_%02d-%02d-%02d" % [
		now.year, now.month, now.day, now.hour, now.minute, now.second]
	var readable := "%04d-%02d-%02d %02d:%02d:%02d" % [
		now.year, now.month, now.day, now.hour, now.minute, now.second]

	var level := LevelLibrary.get_level(GameState.selected_song_id)
	var song_title: String = level.get("title", GameState.selected_song_id)

	var lines := PackedStringArray()
	lines.append("=== Rhythm session log ===")
	lines.append("Date/time:  %s" % readable)
	lines.append("Song:       %s (%s)" % [song_title, GameState.selected_song_id])
	lines.append("Difficulty: %s" % _difficulty_text())
	lines.append("")
	lines.append("Accuracy:    %.2f%%" % GameState.stat_accuracy())
	lines.append("Notes hit:   %d / %d" % [GameState.stat_hits(), GameState.stat_total_notes])
	lines.append("Misses:      %d" % GameState.stat_misses())
	lines.append("")
	lines.append("PERFECT: %d" % GameState.stat_perfect)
	lines.append("GREAT:   %d" % GameState.stat_great)
	lines.append("GOOD:    %d" % GameState.stat_good)
	lines.append("OK:      %d" % GameState.stat_ok)
	lines.append("MISS:    %d" % GameState.stat_misses())

	var path := "%s/%s_%s.txt" % [LOG_DIR, GameState.selected_song_id, stamp]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
		print("Results log written to: ", ProjectSettings.globalize_path(path))
	else:
		push_error("Results: could not write log file to %s" % path)

func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file(GAME_LEVEL_SCENE)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MODE_SELECT_SCENE)
