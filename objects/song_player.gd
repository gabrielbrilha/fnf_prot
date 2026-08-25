extends Node2D

const HUD_FONT := preload("res://art/BubbleBoomRegular-e96nn.ttf")

var _ended: bool = false

# [[start, end], ...] song-time spans that show a full-screen LISTEN overlay:
# black screen, input frozen, no score/combo change. Notes keep falling behind
# it (hidden) so timing stays exact.
var listen_windows: Array = []
var _listen_layer: CanvasLayer
var _listen_on: bool = false

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	GameState.cheat_mode = false

	var level = LevelLibrary.get_level(GameState.selected_song_id)

	$MusicPlayer.stream = load(level.get("music"))
	$MusicPlayer.play()
	BCIMarkers.send_bci_marker("Song_Start")

	Signals.GamePaused.connect(_on_game_paused)

	# LISTEN phases: black-screen spans read from the level, driven in _process
	GameState.listen_active = false
	listen_windows = level.get("listen_windows", [])
	_build_listen_overlay()


	var fk_times_arr = level.get("fk_times")

	var total_notes: int = 0
	var last_hit_time: float = 0.0
	var counter: int  = 0
	for key in fk_times_arr:

		var button_name: String = ""
		match counter:
			0:
				button_name = "button_Q"
			1:
				button_name = "button_W"
			2:
				button_name = "button_E"
			3:
				button_name = "button_R"

		# only lanes enabled by the current mode actually spawn notes
		if GameState.is_key_enabled(button_name):
			total_notes += key.size()
			for delay in key:
				# spawn time is hit_time - FALL_TIME
				last_hit_time = max(last_hit_time, delay + GameState.FALL_TIME)
				SpawnFallingKey(button_name, delay)

		counter += 1

	GameState.reset_stats(total_notes)

	# End the song once both the music and the last note have had time to
	# finish, whichever is longer, plus a short tail
	var song_len: float = $MusicPlayer.stream.get_length() if $MusicPlayer.stream else 0.0
	var end_after: float = max(song_len, last_hit_time) + 1.0
	get_tree().create_timer(end_after, false).timeout.connect(_end_song)


# Toggle the LISTEN overlay based on where the music is. Runs only while
# unpaused (default process mode), so it stays in step with the paused music.
func _process(_delta: float) -> void:
	if _ended:
		return
	var now_listen: bool = _pos_in_listen($MusicPlayer.get_playback_position())
	if now_listen != _listen_on:
		_listen_on = now_listen
		GameState.listen_active = now_listen
		if _listen_layer:
			_listen_layer.visible = now_listen
		# mark the LISTEN/PLAY boundaries for the EEG recording
		BCIMarkers.send_bci_marker("Listen_Start" if now_listen else "Listen_End")

func _pos_in_listen(pos: float) -> bool:
	for w in listen_windows:
		if w.size() >= 2 and pos >= float(w[0]) and pos <= float(w[1]):
			return true
	return false

func _build_listen_overlay() -> void:
	_listen_layer = CanvasLayer.new()
	_listen_layer.layer = 5   # above the notes/HUD (0), below the pause menu (10)
	_listen_layer.visible = false
	add_child(_listen_layer)

	var rect := ColorRect.new()
	# dark but see-through: dims the lanes so the LISTEN text stands out, while
	# the arrows stay visible falling behind it (so the player can track them and
	# is ready to hit the moment input unlocks)
	rect.color = Color(0, 0, 0, 0.72)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_listen_layer.add_child(rect)

	var label := Label.new()
	label.text = "LISTEN"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", HUD_FONT)
	label.add_theme_font_size_override("font_size", 96)
	_listen_layer.add_child(label)


# SPACE toggles cheat mode (autoplay) on and off during the song
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		# the player's spacebar cheat is only allowed on Easy;
		if GameState.selected_difficulty == "EASY":
			GameState.set_cheat_mode(not GameState.cheat_mode)


func SpawnFallingKey(button_name: String, delay: float):
	# process_always = false so the spawn timer freezes while the game is paused,
	# keeping notes aligned with the music
	await get_tree().create_timer(delay, false).timeout
	if _ended:
		return
	Signals.CreateFallingKey.emit(button_name)

	# the arrow reaches the hit line exactly FALL_TIME after spawning
	await get_tree().create_timer(GameState.FALL_TIME, false).timeout
	if _ended:
		return
	BCIMarkers.send_bci_marker("Arrow_" + BCIMarkers.direction_of(button_name) + "_HitZone")

func _on_game_paused(paused: bool) -> void:
	$MusicPlayer.stream_paused = paused


func _on_music_player_finished() -> void:
	_end_song()

# Show the results screen
func _end_song() -> void:
	if _ended:
		return
	_ended = true
	GameState.listen_active = false
	if _listen_layer:
		_listen_layer.visible = false
	BCIMarkers.send_bci_marker("Song_End")
	# reads the stats gathered during the song
	get_tree().change_scene_to_file("res://levels/results_menu.tscn")
