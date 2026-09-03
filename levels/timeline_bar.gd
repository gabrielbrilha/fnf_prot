extends Control

# Timeline for the chart editor. Shows the 4 lane rows plus a 5th LISTEN row
# across the song's duration, with a moving playhead. Top strip = seek;
# left-click a lane = place; right-click a lane = delete nearest. On the LISTEN
# row a left-click sets a span's start then its end (two clicks); right-click
# deletes the span under the cursor. Notes can't go on the LISTEN row and spans
# can't go on the note rows.

signal seek_requested(t: float)
signal place_requested(lane: int, t: float)
signal delete_requested(lane: int, t: float)

const RULER_H := 22.0
const ROWS := 5                                   # 4 note lanes + 1 LISTEN row
const LANE_COLORS := [Color("f2d94e"), Color("46c8e0"), Color("5bd94a"), Color("e0559f")]
const LISTEN_COLOR := Color("cfcfd6")
# generic single-lane colour used in calibrate mode
const CALIBRATE_NOTE_COLOR := Color("c8a2ff")

var song_length: float = 0.0
var playhead_time: float = 0.0
var notes: Array = [[], [], [], []]
var listen_windows: Array = []                    # [[start, end], ...] song time
var listen_pending: float = -1.0                  # first click of a span, or -1

# Calibrate charts are authored on a single generic lane (stored in notes[0])
# plus the LISTEN row, so only two rows are shown.
var single_lane: bool = false

func set_notes(n: Array) -> void:
	notes = n
	queue_redraw()

func set_single_lane(v: bool) -> void:
	single_lane = v
	queue_redraw()

# Rows currently shown, and the index of the LISTEN row within them.
func rows() -> int:
	return 2 if single_lane else ROWS

func note_rows() -> int:
	return 1 if single_lane else 4

func listen_row() -> int:
	return rows() - 1

func set_listen_windows(w: Array) -> void:
	listen_windows = w
	queue_redraw()

func set_listen_pending(t: float) -> void:
	listen_pending = t
	queue_redraw()

func _lane_height() -> float:
	return max(1.0, (size.y - RULER_H) / float(rows()))

func _time_to_x(t: float) -> float:
	if song_length <= 0.0:
		return 0.0
	return clampf(t / song_length, 0.0, 1.0) * size.x

func _lane_at(y: float) -> int:
	return clampi(int((y - RULER_H) / _lane_height()), 0, rows() - 1)

func _row_color(i: int) -> Color:
	if i == listen_row():
		return LISTEN_COLOR
	return CALIBRATE_NOTE_COLOR if single_lane else LANE_COLORS[i]

func _note_color(i: int) -> Color:
	return CALIBRATE_NOTE_COLOR if single_lane else LANE_COLORS[i]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1b1b22"))
	draw_rect(Rect2(0, 0, size.x, RULER_H), Color("2c2c38"))

	var lane_h := _lane_height()
	for i in rows():
		var y := RULER_H + i * lane_h
		var band := Color(1, 1, 1, 0.03) if i % 2 == 0 else Color(1, 1, 1, 0.06)
		draw_rect(Rect2(0, y, size.x, lane_h), band)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.15), 1.0)
		draw_rect(Rect2(0, y, 6, lane_h), _row_color(i))

	# notes on the visible lane rows
	for i in note_rows():
		var y := RULER_H + i * lane_h
		for t in notes[i]:
			var x := _time_to_x(t)
			draw_rect(Rect2(x - 2, y + 3, 4, lane_h - 6), _note_color(i))

	# LISTEN spans on the last row (shaded blocks), plus a pending-start marker
	var ly := RULER_H + listen_row() * lane_h
	for w in listen_windows:
		if w.size() >= 2:
			var x0 := _time_to_x(float(w[0]))
			var x1 := _time_to_x(float(w[1]))
			draw_rect(Rect2(x0, ly + 3, max(2.0, x1 - x0), lane_h - 6), Color(LISTEN_COLOR, 0.30))
			draw_rect(Rect2(x0, ly + 3, max(2.0, x1 - x0), lane_h - 6), Color(LISTEN_COLOR, 0.8), false, 1.0)
	if listen_pending >= 0.0:
		var xp := _time_to_x(listen_pending)
		draw_line(Vector2(xp, ly), Vector2(xp, ly + lane_h), Color("ffd24a"), 2.0)

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
