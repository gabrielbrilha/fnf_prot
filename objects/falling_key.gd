extends Sprite2D

var init_y_position: float = -360

# true if falling key has passed the allowed input  frame
var has_passed: bool = false
var pass_threshold = 300.0

# pixels per second, derived from GameState.FALL_TIME in Setup() so the arrow
# reaches the hit line exactly FALL_TIME seconds after spawning, independent of
# frame rate
var fall_speed: float = 0.0

func _init():
	set_process(false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_position += Vector2(0, fall_speed * delta)

	# Find out how long it takes for arrow to reach the critical spot
	if global_position.y > pass_threshold and not $Timer.is_stopped():
		$Timer.stop()
		has_passed = true

func Setup(target_x: float, target_frame: int):
	global_position = Vector2(target_x, init_y_position)
	frame = target_frame
	fall_speed = (pass_threshold - init_y_position) / GameState.FALL_TIME
	set_process(true)


func _on_destroy_timer_timeout() -> void:
	queue_free()
