extends CanvasLayer

# ESC-triggered pause overlay with Resume / feedback toggle / Back to menu.
# Runs on PROCESS_MODE_ALWAYS (set in the scene) so it still works while the
# rest of the game tree is paused.

const MODE_SELECT_SCENE: String = "res://levels/mode_select.tscn"
const HUD_FONT := preload("res://art/BubbleBoomRegular-e96nn.ttf")

var is_paused: bool = false
var overlay: Control
var feedback_button: Button

func _ready() -> void:
	_build_ui()
	# a freshly loaded game always starts running
	is_paused = false
	get_tree().paused = false
	overlay.visible = false

func _build_ui() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", HUD_FONT)
	title.add_theme_font_size_override("font_size", 60)
	vbox.add_child(title)

	var resume := Button.new()
	resume.text = "Resume"
	resume.custom_minimum_size = Vector2(300, 48)
	resume.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume)

	feedback_button = Button.new()
	feedback_button.custom_minimum_size = Vector2(300, 48)
	feedback_button.pressed.connect(_on_feedback_pressed)
	vbox.add_child(feedback_button)
	_update_feedback_label()

	var back := Button.new()
	back.text = "Back to Menu"
	back.custom_minimum_size = Vector2(300, 48)
	back.pressed.connect(_on_back_pressed)
	vbox.add_child(back)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_paused(not is_paused)
		get_viewport().set_input_as_handled()

func _set_paused(paused: bool) -> void:
	is_paused = paused
	get_tree().paused = paused
	Signals.GamePaused.emit(paused)
	overlay.visible = paused

func _on_resume_pressed() -> void:
	_set_paused(false)

func _on_feedback_pressed() -> void:
	GameState.show_feedback = not GameState.show_feedback
	_update_feedback_label()

func _update_feedback_label() -> void:
	feedback_button.text = "Feedback: " + ("ON" if GameState.show_feedback else "OFF")

func _on_back_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MODE_SELECT_SCENE)
