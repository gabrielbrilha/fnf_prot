extends Control

# Calibrate music-mode picker. Reached from calibrate_select after a level is
# chosen. Shows "Music" and "No Music" buttons, then goes to the song list.

const SONG_SELECT_SCENE: String = "res://levels/song_select.tscn"
const CALIBRATE_SELECT_SCENE: String = "res://levels/calibrate_select.tscn"
const HUD_FONT := preload("res://art/BubbleBoomRegular-e96nn.ttf")

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Level %d — Choose Mode" % GameState.calibrate_level
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", HUD_FONT)
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var btn_music := Button.new()
	btn_music.text = "Music"
	btn_music.custom_minimum_size = Vector2(300, 64)
	btn_music.add_theme_font_override("font", HUD_FONT)
	btn_music.add_theme_font_size_override("font_size", 36)
	btn_music.add_theme_color_override("font_color", Color("22d3e0"))
	btn_music.add_theme_color_override("font_hover_color", Color("22d3e0"))
	btn_music.add_theme_color_override("font_pressed_color", Color("22d3e0"))
	btn_music.add_theme_color_override("font_focus_color", Color("22d3e0"))
	btn_music.pressed.connect(_on_mode_selected.bind("music"))
	vbox.add_child(btn_music)

	var btn_no_music := Button.new()
	btn_no_music.text = "No Music"
	btn_no_music.custom_minimum_size = Vector2(300, 64)
	btn_no_music.add_theme_font_override("font", HUD_FONT)
	btn_no_music.add_theme_font_size_override("font_size", 36)
	btn_no_music.add_theme_color_override("font_color", Color("e01fa0"))
	btn_no_music.add_theme_color_override("font_hover_color", Color("e01fa0"))
	btn_no_music.add_theme_color_override("font_pressed_color", Color("e01fa0"))
	btn_no_music.add_theme_color_override("font_focus_color", Color("e01fa0"))
	btn_no_music.pressed.connect(_on_mode_selected.bind("no_music"))
	vbox.add_child(btn_no_music)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(300, 48)
	back.add_theme_font_override("font", HUD_FONT)
	back.add_theme_font_size_override("font_size", 28)
	back.pressed.connect(_on_back_pressed)
	vbox.add_child(back)

func _on_mode_selected(mode: String) -> void:
	GameState.calibrate_mode = mode
	get_tree().change_scene_to_file(SONG_SELECT_SCENE)

func _on_back_pressed() -> void:
	GameState.calibrate_mode = ""
	get_tree().change_scene_to_file(CALIBRATE_SELECT_SCENE)
