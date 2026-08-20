extends Control

# Main menu. Difficulty is now the top-level choice (zones were removed): pick a
# difficulty here and go straight to the songs for it. Every song plays with all
# four lanes.

const EDITOR_ENABLED: bool = false

const SONG_SELECT_SCENE: String = "res://levels/song_select.tscn"
const HUD_FONT := preload("res://art/BubbleBoomRegular-e96nn.ttf")

# "id" must match the song "difficulty" field; "color" is the button colour
var difficulty_options: Array[Dictionary] = [
	{"id": "EASY", "color": Color("47d147")},
	{"id": "MEDIUM", "color": Color("f2c811")},
	{"id": "HARD", "color": Color("ff4a4a")},
]

func _ready() -> void:
	_build_menu()

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
	if EDITOR_ENABLED:
		var editor_spacer := Control.new()
		editor_spacer.custom_minimum_size = Vector2(0, 12)
		vbox.add_child(editor_spacer)

		var editor_button := Button.new()
		editor_button.text = "Level Editor"
		editor_button.custom_minimum_size = Vector2(300, 40)
		editor_button.pressed.connect(_on_editor_pressed)
		vbox.add_child(editor_button)

func _on_difficulty_selected(difficulty_id: String) -> void:
	GameState.selected_difficulty = difficulty_id
	get_tree().change_scene_to_file(SONG_SELECT_SCENE)

func _on_editor_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/chart_editor.tscn")
