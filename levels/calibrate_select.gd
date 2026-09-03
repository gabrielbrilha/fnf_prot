extends Control

# Calibrate direction picker. Reached from the main-menu "Calibrate" button.
# Shows the four play arrows (Left / Down / Up / Right) in a horizontal row plus
# a Back button to the main menu. Picking an arrow stores that direction and
# opens the calibrate song list, where every calibrate chart plays on that one
# lane (see GameState.effective_fk_times).

const SONG_SELECT_SCENE: String = "res://levels/song_select.tscn"
const MODE_SELECT_SCENE: String = "res://levels/mode_select.tscn"
const HUD_FONT := preload("res://art/BubbleBoomRegular-e96nn.ttf")
const ARROWS := preload("res://art/arrows.webp")

# arrows.webp is a 4x3 sprite sheet; row 0 holds the arrow icons.
const SHEET_COLS: int = 4
const SHEET_ROWS: int = 3

# Lane index -> arrow-sheet frame (row 0). Matches the in-game lanes:
# 0 = Left/Q, 1 = Down/W, 2 = Up/E, 3 = Right/R.
var directions: Array[Dictionary] = [
	{"lane": 0, "frame": 0, "name": "Left"},
	{"lane": 1, "frame": 1, "name": "Down"},
	{"lane": 2, "frame": 2, "name": "Up"},
	{"lane": 3, "frame": 3, "name": "Right"},
]

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Calibrate Direction"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", HUD_FONT)
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	for dir in directions:
		var button := Button.new()
		button.custom_minimum_size = Vector2(110, 110)
		button.icon = _arrow_icon(dir["frame"])
		button.expand_icon = true
		button.tooltip_text = dir["name"]
		button.pressed.connect(_on_direction_selected.bind(dir["lane"]))
		row.add_child(button)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(300, 48)
	back.add_theme_font_override("font", HUD_FONT)
	back.add_theme_font_size_override("font_size", 32)
	back.pressed.connect(_on_back_pressed)
	vbox.add_child(back)

# Build a single-arrow texture from the sprite sheet for the given frame.
func _arrow_icon(frame_idx: int) -> AtlasTexture:
	var fw := float(ARROWS.get_width()) / SHEET_COLS
	var fh := float(ARROWS.get_height()) / SHEET_ROWS
	var col := frame_idx % SHEET_COLS
	var r := int(frame_idx / SHEET_COLS)
	var atlas := AtlasTexture.new()
	atlas.atlas = ARROWS
	atlas.region = Rect2(col * fw, r * fh, fw, fh)
	return atlas

func _on_direction_selected(lane: int) -> void:
	GameState.selected_difficulty = GameState.CALIBRATE_ID
	GameState.calibrate_direction = lane
	get_tree().change_scene_to_file(SONG_SELECT_SCENE)

func _on_back_pressed() -> void:
	GameState.calibrate_direction = -1
	get_tree().change_scene_to_file(MODE_SELECT_SCENE)
