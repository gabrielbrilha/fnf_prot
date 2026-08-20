extends Control

# Timeline for the chart editor. Shows 4 lane rows across the song's duration
# with a moving playhead and the placed notes. Top strip = seek; left-click a
# lane = place; right-click a lane = delete nearest.

signal seek_requested(t: float)
signal place_requested(lane: int, t: float)
signal delete_requested(lane: int, t: float)

const RULER_H := 22.0
const LANE_COLORS := [Color("f2d94e"), Color("46c8e0"), Color("5bd94a"), Color("e0559f")]

var song_length: float = 0.0
var playhead_time: float = 0.0
var notes: Array = [[], [], [], []]

func set_notes(n: Array) -> void:
	notes = n
	queue_redraw()

func _lane_height() -> float:
	return max(1.0, (size.y - RULER_H) / 4.0)

func _time_to_x(t: float) -> float:
	if song_length <= 0.0:
		return 0.0
	return clampf(t / song_length, 0.0, 1.0) * size.x

func _lane_at(y: float) -> int:
	return clampi(int((y - RULER_H) / _lane_height()), 0, 3)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1b1b22"))
	draw_rect(Rect2(0, 0, size.x, RULER_H), Color("2c2c38"))

	var lane_h := _lane_height()
	for i in 4:
		var y := RULER_H + i * lane_h
		var band := Color(1, 1, 1, 0.03) if i % 2 == 0 else Color(1, 1, 1, 0.06)
		draw_rect(Rect2(0, y, size.x, lane_h), band)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.15), 1.0)
		draw_rect(Rect2(0, y, 6, lane_h), LANE_COLORS[i])

	for i in 4:
		var y := RULER_H + i * lane_h
		for t in notes[i]:
			var x := _time_to_x(t)
			draw_rect(Rect2(x - 2, y + 3, 4, lane_h - 6), LANE_COLORS[i])

	var px := _time_to_x(playhead_time)
	draw_line(Vector2(px, 0), Vector2(px, size.y), Color.WHITE, 2.0)

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed) or song_length <= 0.0:
		return
	var t := clampf(event.position.x / size.x, 0.0, 1.0) * song_length
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.y < RULER_H:
			seek_requested.emit(t)
		else:
			place_requested.emit(_lane_at(event.position.y), t)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		delete_requested.emit(_lane_at(event.position.y), t)
