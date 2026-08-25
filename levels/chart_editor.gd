extends Control

# In-game chart editor. Pick a name/difficulty/music, then place notes on a
# timeline (tap Q/W/E/R while it plays, or click a lane), scrub and slow the music
# down for accuracy, and Save -> writes a JSON level via LevelLibrary that shows
# up in the picker on the next run.

const MODE_SELECT_SCENE := "res://levels/mode_select.tscn"
const TimelineBar := preload("res://levels/timeline_bar.gd")

# zones were removed from the game; saved levels just use "NORMAL"
const DIFFICULTIES := ["EASY", "MEDIUM", "HARD", "CALIBRATE"]
const SPEEDS := [0.25, 0.5, 1.0]
const LANE_ACTIONS := ["button_Q", "button_W", "button_E", "button_R"]
const LANE_NAMES := ["Left (Q)", "Down (W)", "Up (E)", "Right (R)"]

var music: AudioStreamPlayer
var timeline
var name_edit: LineEdit
var diff_option: OptionButton
var music_option: OptionButton
var status_label: Label

var note_times: Array = [[], [], [], []]   # per lane: HIT times (song seconds)
var last_added: Array = []                 # [lane, t] stack for Undo

var listen_windows: Array = []             # [[start, end], ...] song seconds
var listen_pending: float = -1.0           # first click of a LISTEN span, or -1
var loaded_id: String = ""                 # set when editing an existing level

var current_music_path: String = ""
var song_length: float = 0.0
var current_time: float = 0.0
var is_playing: bool = false
var speed: float = 1.0

func _ready() -> void:
	music = AudioStreamPlayer.new()
	add_child(music)
	music.finished.connect(_on_music_finished)
	_build_ui()
	_list_music()

	# opened via a pencil button -> load that level for editing
	if GameState.edit_level_id != "":
		_load_existing(GameState.edit_level_id)
		GameState.edit_level_id = ""

func _process(_delta: float) -> void:
	if is_playing:
		current_time = music.get_playback_position()
	_place_from_keys()
	timeline.playhead_time = current_time
	timeline.queue_redraw()

# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("12121a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Level Editor"
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)

	# --- setup row: name / difficulty ---
	var setup := HBoxContainer.new()
	setup.add_theme_constant_override("separation", 8)
	root.add_child(setup)

	setup.add_child(_label("Name:"))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Level name"
	name_edit.custom_minimum_size = Vector2(220, 0)
	setup.add_child(name_edit)

	setup.add_child(_label("Difficulty:"))
	diff_option = OptionButton.new()
	for d in DIFFICULTIES:
		diff_option.add_item(d)
	diff_option.selected = DIFFICULTIES.find("MEDIUM")
	setup.add_child(diff_option)

	# --- music row ---
	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 8)
	root.add_child(music_row)

	music_row.add_child(_label("Music:"))
	music_option = OptionButton.new()
	music_option.custom_minimum_size = Vector2(280, 0)
	music_option.item_selected.connect(_on_music_selected)
	music_row.add_child(music_option)

	# --- legend ---
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 16)
	root.add_child(legend)
	for i in 4:
		var swatch := Label.new()
		swatch.text = "■ " + LANE_NAMES[i]
		swatch.add_theme_color_override("font_color", TimelineBar.LANE_COLORS[i])
		legend.add_child(swatch)
	var listen_swatch := Label.new()
	listen_swatch.text = "■ LISTEN"
	listen_swatch.add_theme_color_override("font_color", TimelineBar.LISTEN_COLOR)
	legend.add_child(listen_swatch)

	# --- timeline ---
	timeline = TimelineBar.new()
	timeline.custom_minimum_size = Vector2(0, 230)
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	timeline.seek_requested.connect(_on_seek)
	timeline.place_requested.connect(_on_place)
	timeline.delete_requested.connect(_on_delete)
	root.add_child(timeline)
	timeline.set_listen_windows(listen_windows)

	# --- transport row ---
	var transport := HBoxContainer.new()
	transport.add_theme_constant_override("separation", 8)
	root.add_child(transport)

	transport.add_child(_button("Play", _on_play))
	transport.add_child(_button("Pause", _on_pause))
	transport.add_child(_button("Reset", _on_reset))

	transport.add_child(_label("Speed:"))
	var speed_option := OptionButton.new()
	for s in SPEEDS:
		speed_option.add_item(str(s) + "x")
	speed_option.selected = SPEEDS.find(1.0)
	speed_option.item_selected.connect(_on_speed_selected)
	transport.add_child(speed_option)

	transport.add_child(_button("Undo", _on_undo))
	transport.add_child(_button("Clear", _on_clear))

	# --- bottom row: save / back / status ---
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)

	bottom.add_child(_button("Save", _on_save))
	bottom.add_child(_button("Back", _on_back))
	status_label = Label.new()
	bottom.add_child(status_label)

	var hint := Label.new()
	hint.text = "Play the music and tap Q/W/E/R to place notes. Click a lane to place, right-click to delete, click the top strip to seek. On the LISTEN row, click once for a span's start then again for its end (right-click a span to delete). Slow the speed down for accuracy."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	_update_status()

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(90, 36)
	b.pressed.connect(handler)
	return b

# ---------------------------------------------------------------- music

func _list_music() -> void:
	music_option.clear()
	var dir := DirAccess.open("res://music")
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".wav") or f.ends_with(".ogg") or f.ends_with(".mp3"):
			music_option.add_item(f)
			music_option.set_item_metadata(music_option.get_item_count() - 1, "res://music/" + f)
	if music_option.get_item_count() > 0:
		_load_music(music_option.get_item_metadata(0))

func _on_music_selected(idx: int) -> void:
	_load_music(music_option.get_item_metadata(idx))

func _load_music(path: String) -> void:
	current_music_path = path
	music.stop()
	is_playing = false
	current_time = 0.0
	music.stream = load(path)
	song_length = music.stream.get_length() if music.stream else 0.0
	timeline.song_length = song_length
	timeline.playhead_time = 0.0
	timeline.queue_redraw()
	_update_status()

# ---------------------------------------------------------------- transport

func _on_play() -> void:
	if song_length <= 0.0:
		return
	music.pitch_scale = speed
	music.play(current_time)
	is_playing = true

func _on_pause() -> void:
	if is_playing:
		current_time = music.get_playback_position()
		music.stop()
		is_playing = false

func _on_reset() -> void:
	music.stop()
	is_playing = false
	current_time = 0.0

func _on_music_finished() -> void:
	is_playing = false
	current_time = song_length

func _on_speed_selected(idx: int) -> void:
	speed = SPEEDS[idx]
	music.pitch_scale = speed

func _on_seek(t: float) -> void:
	current_time = clampf(t, 0.0, song_length)
	if is_playing:
		music.seek(current_time)

# ---------------------------------------------------------------- notes

func _place_from_keys() -> void:
	if song_length <= 0.0 or name_edit.has_focus():
		return
	for lane in 4:
		if Input.is_action_just_pressed(LANE_ACTIONS[lane]):
			_add_note(lane, current_time)

func _add_note(lane: int, t: float) -> void:
	note_times[lane].append(t)
	last_added.append([lane, t])
	timeline.set_notes(note_times)
	_update_status()

func _on_place(lane: int, t: float) -> void:
	if lane == TimelineBar.LISTEN_ROW:
		_listen_click(t)
	else:
		_add_note(lane, t)

# Two-click LISTEN span placement: first click sets the start, second the end.
func _listen_click(t: float) -> void:
	if listen_pending < 0.0:
		listen_pending = t
		timeline.set_listen_pending(t)
		_update_status()
		return
	var s: float = min(listen_pending, t)
	var e: float = max(listen_pending, t)
	listen_pending = -1.0
	timeline.set_listen_pending(-1.0)
	if e - s > 0.01:
		listen_windows.append([snappedf(s, 0.0001), snappedf(e, 0.0001)])
		listen_windows.sort_custom(func(a, b): return a[0] < b[0])
		timeline.set_listen_windows(listen_windows)
	_update_status()

func _delete_listen(t: float) -> void:
	for i in listen_windows.size():
		var w = listen_windows[i]
		if t >= w[0] and t <= w[1]:
			listen_windows.remove_at(i)
			timeline.set_listen_windows(listen_windows)
			_update_status()
			return

func _on_delete(lane: int, t: float) -> void:
	if lane == TimelineBar.LISTEN_ROW:
		_delete_listen(t)
		return
	var best := -1
	var best_dist := 0.3
	for i in note_times[lane].size():
		var d: float = abs(note_times[lane][i] - t)
		if d < best_dist:
			best_dist = d
			best = i
	if best >= 0:
		note_times[lane].remove_at(best)
		timeline.set_notes(note_times)
		_update_status()

func _on_undo() -> void:
	if last_added.is_empty():
		return
	var e = last_added.pop_back()
	var idx: int = note_times[e[0]].find(e[1])
	if idx >= 0:
		note_times[e[0]].remove_at(idx)
	timeline.set_notes(note_times)
	_update_status()

func _on_clear() -> void:
	note_times = [[], [], [], []]
	last_added.clear()
	timeline.set_notes(note_times)
	_update_status()

# ---------------------------------------------------------------- save

func _on_save() -> void:
	# editing an existing level keeps its id (overwrites in place); a new level
	# derives the id from the name
	var id := loaded_id if loaded_id != "" else _sanitize_id(name_edit.text)
	if id == "":
		status_label.text = "Enter a name first."
		return
	if current_music_path == "":
		status_label.text = "Pick a music file first."
		return

	# store spawn times (hit time - fall time), dropping any that can't fit on screen
	var fk_times := [[], [], [], []]
	for lane in 4:
		var arr := []
		for t in note_times[lane]:
			var spawn: float = t - GameState.FALL_TIME
			if spawn >= 0.0:
				arr.append(snappedf(spawn, 0.0001))
		arr.sort()
		fk_times[lane] = arr

	var data := {
		"id": id,
		"title": name_edit.text.strip_edges(),
		"zone": "NORMAL",
		"difficulty": DIFFICULTIES[diff_option.selected],
		"music": current_music_path,
		"fk_times": fk_times,
		"listen_windows": listen_windows,
	}

	var path := LevelLibrary.save_level(id, data)
	status_label.text = ("Saved '%s' (%d notes) -> %s" %
		[id, _total_notes(), path]) if path != "" else "Save failed."

func _sanitize_id(raw: String) -> String:
	var out := ""
	for c in raw.strip_edges().to_upper():
		if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			out += c
		elif c == " " or c == "_" or c == "-":
			out += "_"
	return out

func _total_notes() -> int:
	var n := 0
	for lane in note_times:
		n += lane.size()
	return n

func _update_status() -> void:
	if not status_label:
		return
	var counts := []
	for lane in note_times:
		counts.append(lane.size())
	var extra := ""
	if listen_pending >= 0.0:
		extra = "   [LISTEN start @ %.2fs - click end]" % listen_pending
	status_label.text = "Notes L/D/U/R: %s   LISTEN: %d   length: %.1fs%s" % [
		str(counts), listen_windows.size(), song_length, extra]

# Load an existing level into the editor (from a pencil button). Notes are stored
# as spawn times but edited as hit times, so convert on the way in.
func _load_existing(id: String) -> void:
	var level = LevelLibrary.get_level(id)
	if level.is_empty():
		return
	loaded_id = id
	name_edit.text = str(level.get("title", ""))

	var di: int = DIFFICULTIES.find(str(level.get("difficulty", "")))
	diff_option.selected = di if di >= 0 else 0

	var mpath := str(level.get("music", ""))
	for i in music_option.get_item_count():
		if music_option.get_item_metadata(i) == mpath:
			music_option.selected = i
			_load_music(mpath)
			break

	note_times = [[], [], [], []]
	var fk = level.get("fk_times", [[], [], [], []])
	for lane in 4:
		if lane < fk.size():
			for spawn in fk[lane]:
				note_times[lane].append(float(spawn) + GameState.FALL_TIME)
	last_added.clear()
	timeline.set_notes(note_times)

	listen_windows = level.get("listen_windows", []).duplicate(true)
	timeline.set_listen_windows(listen_windows)
	_update_status()

func _on_back() -> void:
	get_tree().change_scene_to_file(MODE_SELECT_SCENE)
