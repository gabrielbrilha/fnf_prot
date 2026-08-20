extends Node2D

var _ended: bool = false

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	GameState.cheat_mode = false

	var level = LevelLibrary.get_level(GameState.selected_song_id)

	$MusicPlayer.stream = load(level.get("music"))
	$MusicPlayer.play()
	BCIMarkers.send_bci_marker("Song_Start")

	Signals.GamePaused.connect(_on_game_paused)


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
	BCIMarkers.send_bci_marker("Song_End")
	# reads the stats gathered during the song
	get_tree().change_scene_to_file("res://levels/results_menu.tscn")
