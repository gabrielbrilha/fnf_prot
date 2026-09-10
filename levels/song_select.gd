extends Control

# Song list for the chosen difficulty (or calibrate level + mode).
# Layout:
#   ┌─────────────────────────────┐
#   │  Title / Subtitle           │  ← fixed header
#   ├─────────────────────────────┤
#   │  ScrollContainer            │  ← grows to fill remaining space
#   │    GridContainer (2 cols)   │
#   │      [Song A] [✏]  [Song B] [✏]   │
#   │      [Song C] [✏]  ...      │
#   ├─────────────────────────────┤
#   │  [ Back ]                   │  ← always visible at the bottom
#   └─────────────────────────────┘

const GAME_LEVEL_SCENE: String = "res://levels/game_level.tscn"
const MODE_SELECT_SCENE: String = "res://levels/mode_select.tscn"
const CALIBRATE_SELECT_SCENE: String = "res://levels/calibrate_select.tscn"
const CALIBRATE_MUSIC_SELECT_SCENE: String = "res://levels/calibrate_music_select.tscn"
const CHART_EDITOR_SCENE: String = "res://levels/chart_editor.tscn"

const HUD_FONT := preload("res://art/BubbleBoomRegular-e96nn.ttf")

# Number of song columns in the grid.
const COLUMNS: int = 2

func _ready() -> void:
	# ── Outer layout: full-rect VBox with margin ──────────────────────────────
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   40)
	margin.add_theme_constant_override("margin_right",  40)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	# ── Header ────────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "Select Song"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", HUD_FONT)
	title.add_theme_font_size_override("font_size", 36)
	outer.add_child(title)

	var subtitle := Label.new()
	subtitle.text = _subtitle_text()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	outer.add_child(subtitle)

	# ── ScrollContainer (fills the space between header and Back) ─────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	# ── Song grid inside the scroll ───────────────────────────────────────────
	var song_ids := _songs_for_difficulty()

	if song_ids.is_empty():
		var empty := Label.new()
		empty.text = "No songs here yet"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(empty)
	else:
		# Each "cell" is an HBoxContainer holding [play_button] + optional [edit_button].
		# We arrange these cells in a GridContainer with COLUMNS columns.
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 10)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)

		for id in song_ids:
			var cell := HBoxContainer.new()
			cell.add_theme_constant_override("separation", 4)
			# Make each cell fill its grid column equally
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(cell)

			var button := Button.new()
			button.text = LevelLibrary.get_all()[id]["title"]
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size = Vector2(0, 48)
			button.pressed.connect(_on_song_selected.bind(id))
			cell.add_child(button)

			# Edit (pencil) button — only when the level editor is enabled
			if GameState.EDITOR_ENABLED:
				var edit := Button.new()
				edit.text = "✏"
				edit.tooltip_text = "Edit in level editor"
				edit.custom_minimum_size = Vector2(44, 48)
				edit.pressed.connect(_on_edit_pressed.bind(id))
				cell.add_child(edit)

		# If the number of songs is odd, pad the last row so the grid stays tidy
		if song_ids.size() % COLUMNS != 0:
			var pad := Control.new()
			pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(pad)

	# ── Back button — always visible below the scroll ─────────────────────────
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(200, 44)
	back.add_theme_font_override("font", HUD_FONT)
	back.add_theme_font_size_override("font_size", 28)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_on_back_pressed)
	outer.add_child(back)

# ── Filtering ─────────────────────────────────────────────────────────────────

# Songs matching the selected difficulty. In calibrate mode the list is filtered
# by calibrate_level and calibrate_mode (both must match).
func _songs_for_difficulty() -> Array:
	var result: Array = []
	for id in LevelLibrary.get_all():
		var level = LevelLibrary.get_all()[id]
		if GameState.has_difficulty() and level.get("difficulty", "") != GameState.selected_difficulty:
			continue
		if GameState.is_calibrating():
			if GameState.calibrate_level >= 1 \
					and int(level.get("calibrate_level", -1)) != GameState.calibrate_level:
				continue
			if GameState.calibrate_mode != "" \
					and str(level.get("calibrate_mode", "")) != GameState.calibrate_mode:
				continue
		result.append(id)
	return result

# ── Handlers ──────────────────────────────────────────────────────────────────

func _on_song_selected(song_id: String) -> void:
	GameState.selected_song_id = song_id
	get_tree().change_scene_to_file(GAME_LEVEL_SCENE)

func _on_edit_pressed(song_id: String) -> void:
	GameState.edit_level_id = song_id
	get_tree().change_scene_to_file(CHART_EDITOR_SCENE)

# Header subtitle: shows calibrate level + mode when calibrating.
func _subtitle_text() -> String:
	if not GameState.has_difficulty():
		return ""
	if GameState.is_calibrating():
		var parts: Array[String] = ["CALIBRATE"]
		if GameState.calibrate_level >= 1:
			parts.append("Level %d" % GameState.calibrate_level)
		if GameState.calibrate_mode != "":
			parts.append(GameState.calibrate_mode.replace("_", " ").to_upper())
		return " — ".join(parts)
	return GameState.selected_difficulty

# Back: calibrate flow has two intermediary screens; go back one step at a time.
func _on_back_pressed() -> void:
	if GameState.is_calibrating():
		get_tree().change_scene_to_file(CALIBRATE_MUSIC_SELECT_SCENE)
	else:
		get_tree().change_scene_to_file(MODE_SELECT_SCENE)
