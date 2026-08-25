extends Node

const ALL_KEYS: Array[String] = ["button_Q", "button_W", "button_E", "button_R"]

# Seconds a falling arrow takes to travel from spawn to the hit line
const FALL_TIME: float = 2.2

# Master switch for the in-game level editor: the "Level Editor" menu button and
# the per-song pencil (edit) buttons all check this.
const EDITOR_ENABLED: bool = false

var selected_song_id: String = ""

# When set, the chart editor opens editing this existing level instead of a new
# one. Cleared by the editor once it has loaded it.
var edit_level_id: String = ""

# True while a LISTEN screen is up: black screen, input frozen, and no score or
# combo change (even accidental presses). Driven by song_player from the level's
# listen_windows.
var listen_active: bool = false

# When true the game auto-plays the notes
# no score or combo
var cheat_mode: bool = false

# Single entry point for turning cheat mode on/off, used by both the local
# spacebar and the remote control panel so they behave the same.
# Clears the combo when cheating starts
func set_cheat_mode(enabled: bool) -> void:
	if enabled and not cheat_mode:
		Signals.ResetCombo.emit()
	cheat_mode = enabled

# When true, the local keyboard is ignored for hitting notes and only external
# presses reach the lanes
var external_input: bool = false

# Single entry point for turning external-input mode on/off, mirroring
func set_external_input(enabled: bool) -> void:
	external_input = enabled

# When false, the PERFECT/GREAT/GOOD/OK/MISS popups are hidden. Off by default;
# toggled from the pause menu.
var show_feedback: bool = false

# Counted every song regardless of show_feedback
var stat_perfect: int = 0
var stat_great: int = 0
var stat_good: int = 0
var stat_ok: int = 0
# Notes that should have been hit
var stat_total_notes: int = 0

func reset_stats(total_notes: int) -> void:
	stat_perfect = 0
	stat_great = 0
	stat_good = 0
	stat_ok = 0
	stat_total_notes = total_notes

# Tally a successful hit by its judgment. Misses aren't recorded here as a note
# is either hit or missed, so misses = total - hits.
func record_hit(result: String) -> void:
	match result:
		"PERFECT": stat_perfect += 1
		"GREAT": stat_great += 1
		"GOOD": stat_good += 1
		"OK": stat_ok += 1

func stat_hits() -> int:
	return stat_perfect + stat_great + stat_good + stat_ok

func stat_misses() -> int:
	return max(0, stat_total_notes - stat_hits())

# Timing accuracy: each hit weighted by how clean it was, averaged over every
# note that should have been hit (missed notes count as 0). 
# PERFECT=100%, GREAT=75%, GOOD=50%, OK=25%.
func stat_accuracy() -> float:
	if stat_total_notes <= 0:
		return 0.0
	var weighted: float = stat_perfect * 1.0 + stat_great * 0.75 + stat_good * 0.5 + stat_ok * 0.25
	return weighted / float(stat_total_notes) * 100.0

# Difficulty chosen on the main menu.
var selected_difficulty: String = ""

func has_difficulty() -> bool:
	return selected_difficulty != ""

# Zones were removed, so every lane is always active. Kept as a single gate so
# key_listener / song_player don't have to special-case anything.
func is_key_enabled(key_name: String) -> bool:
	return ALL_KEYS.has(key_name)
