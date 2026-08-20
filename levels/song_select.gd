extends Control

# Song list for the chosen difficulty. Reached from the difficulty menu; "Back"
# returns there to pick another difficulty.

const GAME_LEVEL_SCENE: String = "res://levels/game_level.tscn"
const MODE_SELECT_SCENE: String = "res://levels/mode_select.tscn"

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Select Music"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = GameState.selected_difficulty if GameState.has_difficulty() else ""
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	var song_ids := _songs_for_difficulty()
	if song_ids.is_empty():
		var empty := Label.new()
		empty.text = "No songs here yet"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty)
	else:
		for id in song_ids:
			var button := Button.new()
			button.text = LevelLibrary.get_all()[id]["title"]
			button.custom_minimum_size = Vector2(280, 44)
			button.pressed.connect(_on_song_selected.bind(id))
			vbox.add_child(button)

	# Back to the difficulty menu to choose a different difficulty
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(280, 36)
	back.pressed.connect(_on_back_pressed)
	vbox.add_child(back)

# Songs matching the selected difficulty (zones removed).
func _songs_for_difficulty() -> Array:
	var result: Array = []
	for id in LevelLibrary.get_all():
		var level = LevelLibrary.get_all()[id]
		if not GameState.has_difficulty() or level.get("difficulty", "") == GameState.selected_difficulty:
			result.append(id)
	return result

func _on_song_selected(song_id: String) -> void:
	GameState.selected_song_id = song_id
	get_tree().change_scene_to_file(GAME_LEVEL_SCENE)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MODE_SELECT_SCENE)
