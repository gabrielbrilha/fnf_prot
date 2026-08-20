extends Control

var score: int = 0
var combo_count: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Signals.IncrementScore.connect(IncrementScore)
	Signals.IncrementCombo.connect(IncrementCombo)
	Signals.ResetCombo.connect(ResetCombo)
	
	ResetCombo()


func _process(_delta: float) -> void:
	# show the cheat indicator only while cheat mode is active
	%CheatLabel.visible = GameState.cheat_mode

func IncrementScore(incr: int):
	score += incr
	%ScoreLabel.text = " " + str(score) + " pts"

func IncrementCombo():
	combo_count += 1
	%ComboLabel.text =  " " + str(combo_count) + "x combo"


func ResetCombo():
	combo_count = 0
	%ComboLabel.text = ""
