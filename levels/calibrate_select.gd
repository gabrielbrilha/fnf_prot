extends Control

# Calibrate level picker. Reached from the main-menu "Calibrate" button.
# Shows Level 1 / Level 2 / Level 3 buttons plus a Back button.
# Picking a level stores the calibrate_level in GameState and opens the
# music-mode picker (calibrate_music_select).

const MUSIC_SELECT_SCENE: String = "res://levels/calibrate_music_select.tscn"
const MODE_SELECT_SCENE: String = "res://levels/mode_select.tscn"
const HUD_FONT := preload("res://art/BubbleBoomRegular-e96nn.ttf")

var levels: Array[Dictionary] = [
	{"num": 1, "label": "Level 1", "color": Color("47d147")},
	{"num": 2, "label": "Level 2", "color": Color("f2c811")},
	{"num": 3, "label": "Level 3", "color": Color("ff4a4a")},
]

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Select Level"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", HUD_FONT)
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	for lvl in levels:
		var button := Button.new()
		button.text = lvl["label"]
		button.custom_minimum_size = Vector2(300, 64)
		button.add_theme_font_override("font", HUD_FONT)
		button.add_theme_font_size_override("font_size", 36)
		var color: Color = lvl["color"]
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", color)
		button.add_theme_color_override("font_pressed_color", color)
		button.add_theme_color_override("font_focus_color", color)
		button.pressed.connect(_on_level_selected.bind(lvl["num"]))
		vbox.add_child(button)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(300, 48)
	back.add_theme_font_override("font", HUD_FONT)
	back.add_theme_font_size_override("font_size", 28)
	back.pressed.connect(_on_back_pressed)
	vbox.add_child(back)

func _on_level_selected(level_num: int) -> void:
	GameState.selected_difficulty = GameState.CALIBRATE_ID
	GameState.calibrate_level = level_num
	GameState.calibrate_mode = ""
	get_tree().change_scene_to_file(MUSIC_SELECT_SCENE)

func _on_back_pressed() -> void:
	GameState.calibrate_level = -1
	GameState.calibrate_mode = ""
	get_tree().change_scene_to_file(MODE_SELECT_SCENE)
