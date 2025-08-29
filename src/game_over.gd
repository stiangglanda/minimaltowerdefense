extends CanvasLayer

@onready var end_game_label = $Control
@onready var Highscore = $Control/ColorRect/VBoxContainer/HBoxContainer/Highscore

var HighscoreCount = 0

var is_game_over = false

func end_game():
	if is_game_over:
		return
	
	is_game_over = true
	
	Highscore.text = str(HighscoreCount)
	end_game_label.visible = true
	
	get_tree().paused = true
	await get_tree().create_timer(3.0).timeout
	get_tree().paused = false
	get_tree().reload_current_scene()
	
func IncreseHighscore(gold_value):
	HighscoreCount=HighscoreCount+gold_value
