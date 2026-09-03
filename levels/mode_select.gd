extends Control

# Main menu. Difficulty is now the top-level choice (zones were removed): pick a
# difficulty here and go straight to the songs for it. Every song plays with all
# four lanes.

const SONG_SELECT_SCENE: String = "res://levels/song_select.tscn"
const CALIBRATE_SELECT_SCENE: String = "res://levels/calibrate_select.tscn"
const HUD_FONT := preload("res://art/BubbleBoomRegular-e96nn.ttf")

# "id" must match the song "difficulty" field; "color" is the button colour
var difficulty_options: Array[Dictionary] = [
	{"id": "EASY", "color": Color("47d147")},
	{"id": "MEDIUM", "color": Color("f2c811")},
	{"id": "HARD", "color": Color("ff4a4a")},
]

func _ready() -> void:
	_build_menu()
	_build_calibrate_button()

func _build_menu() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Select Difficulty"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", HUD_FONT)
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	for option in difficulty_options:
		var button := Button.new()
		button.text = option["id"]
		button.custom_minimum_size = Vector2(300, 64)
		button.add_theme_font_override("font", HUD_FONT)
		button.add_theme_font_size_override("font_size", 40)
		var color: Color = option["color"]
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", color)
		button.add_theme_color_override("font_pressed_color", color)
		button.add_theme_color_override("font_focus_color", color)
		button.pressed.connect(_on_difficulty_selected.bind(option["id"]))
		vbox.add_child(button)

	# Level Editor entry (dev-only)
	if GameState.EDITOR_ENABLED:
		var editor_spacer := Control.new()
		editor_spacer.custom_minimum_size = Vector2(0, 12)
		vbox.add_child(editor_spacer)

		var editor_button := Button.new()
		editor_button.text = "Level Editor"
		editor_button.custom_minimum_size = Vector2(300, 40)
		editor_button.pressed.connect(_on_editor_pressed)
		vbox.add_child(editor_button)

# "Calibrate" button pinned to the top-right corner: its own category of
# tutorial/calibration songs (difficulty "CALIBRATE"), separate from the
# EASY/MEDIUM/HARD picker.
func _build_calibrate_button() -> void:
	var button := Button.new()
	button.text = "Calibrate"
	button.add_theme_font_override("font", HUD_FONT)
	button.add_theme_font_size_override("font_size", 26)
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 0.0
	button.anchor_bottom = 0.0
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.offset_left = -200.0
	button.offset_top = 20.0
	button.offset_right = -20.0
	button.offset_bottom = 68.0
	button.pressed.connect(_on_calibrate_pressed)
	add_child(button)

func _on_difficulty_selected(difficulty_id: String) -> void:
	GameState.selected_difficulty = difficulty_id
	GameState.calibrate_direction = -1   # only calibrate mode remaps lanes
	get_tree().change_scene_to_file(SONG_SELECT_SCENE)

# Calibrate first asks which direction to calibrate, then shows the songs.
func _on_calibrate_pressed() -> void:
	GameState.selected_difficulty = GameState.CALIBRATE_ID
	GameState.calibrate_direction = -1
	get_tree().change_scene_to_file(CALIBRATE_SELECT_SCENE)

func _on_editor_pressed() -> void:
	GameState.edit_level_id = ""   # new level, not editing an existing one
	get_tree().change_scene_to_file("res://levels/chart_editor.tscn")
