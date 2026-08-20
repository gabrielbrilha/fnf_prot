extends Sprite2D

@onready var falling_key = preload("res://objects/falling_key.tscn")
@onready var score_text = preload("res://objects/score_press_text.tscn")
@export var key_name: String = ""

var falling_key_queue = []

# if distance_from_pass is less than threshold, give that score
var perfect_press_threshold: float = 30
var great_press_threshold: float = 50
var good_press_threshold: float = 60
var ok_press_threshold: float = 80
# otherwise, miss

var perfect_press_score: float = 250
var great_press_score: float = 100
var good_press_score: float = 50
var ok_press_score: float = 20

var glow_fade_duration: float = 0.15
var glow_tween: Tween

# internal judgment tier -> BCI marker judgement name
const JUDGEMENT := {
	"PERFECT": "Perfect",
	"GREAT": "Great",
	"GOOD": "Good",
	"OK": "Ok",
	"MISS": "Miss",
}

# arrow direction for this lane ("Left"/"Down"/"Up"/"Right"), for marker names
var _dir: String = ""

func _ready() -> void:
	if not GameState.is_key_enabled(key_name):
		$RandomSpawnTimer.stop()

	_dir = BCIMarkers.direction_of(key_name)
	$GlowOverlay.frame = frame + 4
	$GlowOverlay.visible = false
	Signals.CreateFallingKey.connect(CreateFallingKey)
	Signals.ExternalKeyPressed.connect(_on_external_key_pressed)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):

	# player-input marker: fires on the real key press for this lane whether or
	# not a note is waiting.
	if GameState.is_key_enabled(key_name) and not GameState.external_input \
			and Input.is_action_just_pressed(key_name):
		BCIMarkers.send_bci_marker(_dir + "_Pressed")

	# make sure there is a falling key to check for this given key
	if falling_key_queue.size() > 0:

		# Cheat mode: auto-hit each note when it reaches the hit line, no score/combo
		if GameState.cheat_mode:
			var front_key = falling_key_queue.front()
			if front_key.global_position.y >= front_key.pass_threshold:
				falling_key_queue.pop_front()
				front_key.queue_free()
				OverlayGlow()
				# auto-hits land perfectly; tally it for the results screen
				# regardless of whether the popup is shown
				GameState.record_hit("PERFECT")
				BCIMarkers.send_bci_marker(_dir + "_" + JUDGEMENT["PERFECT"])
				# show it too, but only if feedback is enabled in the pause menu
				if GameState.show_feedback:
					var st_inst = score_text.instantiate()
					get_tree().get_root().call_deferred("add_child", st_inst)
					st_inst.SetTextInfo("PERFECT")
					st_inst.global_position = global_position + Vector2(0, -20)
			return

		# if that falling key has passed, remove it from the queue
		if falling_key_queue.front().has_passed:
			falling_key_queue.pop_front()

			BCIMarkers.send_bci_marker(_dir + "_" + JUDGEMENT["MISS"])

			# PRINT MISS
			if GameState.show_feedback:
				var st_inst = score_text.instantiate()
				get_tree().get_root().call_deferred("add_child", st_inst)
				st_inst.SetTextInfo("MISS")
				st_inst.global_position = global_position + Vector2(0, -20)
			Signals.ResetCombo.emit()

	
		# local keyboard press. While external-input mode is on the in-game
		# player's keyboard is ignored
		if not GameState.external_input and Input.is_action_just_pressed(key_name) and falling_key_queue.size() > 0:
			_try_hit(true)


# Judge a press against the front falling key
func _try_hit(award: bool) -> void:
	var front_key = falling_key_queue.front()
	var distance_from_pass = abs(front_key.pass_threshold - front_key.global_position.y)

	# too early: the note is still far from the line, so ignore the press
	# and leave it falling instead of consuming it
	if distance_from_pass >= ok_press_threshold:
		return

	falling_key_queue.pop_front()

	var press_score_text: String = ""
	if distance_from_pass < perfect_press_threshold:
		press_score_text = "PERFECT"
		if award:
			Signals.IncrementScore.emit(perfect_press_score)
	elif distance_from_pass < great_press_threshold:
		press_score_text = "GREAT"
		if award:
			Signals.IncrementScore.emit(great_press_score)
	elif distance_from_pass < good_press_threshold:
		press_score_text = "GOOD"
		if award:
			Signals.IncrementScore.emit(good_press_score)
	else:
		press_score_text = "OK"
		if award:
			Signals.IncrementScore.emit(ok_press_score)

	# tally the hit for the results screen
	GameState.record_hit(press_score_text)
	BCIMarkers.send_bci_marker(_dir + "_" + JUDGEMENT[press_score_text])

	# external presses never build combo
	if award:
		Signals.IncrementCombo.emit()

	front_key.queue_free()

	# judgment popup only when feedback is enabled
	if GameState.show_feedback:
		var st_inst = score_text.instantiate()
		get_tree().get_root().call_deferred("add_child", st_inst)
		st_inst.SetTextInfo(press_score_text)
		st_inst.global_position = global_position + Vector2(0, -20)

	OverlayGlow()


# A press coming from the experimenter web panel. Only honored while
# external-input mode is on; hits the note but awards no score/combo.
func _on_external_key_pressed(button_name: String) -> void:
	if not GameState.external_input:
		return
	if button_name != key_name or not GameState.is_key_enabled(key_name):
		return
	# external presses are honored input too, so mark them the same way
	BCIMarkers.send_bci_marker(_dir + "_Pressed")
	if falling_key_queue.size() > 0:
		_try_hit(false)
	
	

func OverlayGlow() -> void:
	if glow_tween:
		glow_tween.kill()

	$GlowOverlay.visible = true
	$GlowOverlay.modulate.a = 1.0

	glow_tween = create_tween()
	glow_tween.tween_property($GlowOverlay, "modulate:a", 0.0, glow_fade_duration)
	glow_tween.tween_callback($GlowOverlay.hide)


func CreateFallingKey(button_name: String):
	if button_name == key_name and GameState.is_key_enabled(key_name):
		var fk_inst = falling_key.instantiate()
		get_tree().get_root().call_deferred("add_child", fk_inst)
		fk_inst.Setup(position.x, frame + 4)

		falling_key_queue.push_back(fk_inst)
		BCIMarkers.send_bci_marker("Arrow_" + _dir + "_Spawn")


func _on_random_spawn_timer_timeout() -> void:
	#CreateFallingKey()
	$RandomSpawnTimer.wait_time = randf_range(0.4, 3)
	$RandomSpawnTimer.start()
