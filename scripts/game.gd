extends Node2D

var time_left := 0.0

@onready var time_label: Label = $HUD/StatsBox/TimeLabel


func _ready() -> void:
	get_tree().paused = false
	GameState.reset()

	GameState.game_lost.connect(_on_game_lost)

	time_left = GameState.round_time
	_update_time_label()
	GameState.running = true


func _process(delta: float) -> void:
	if not GameState.running or GameState.game_over:
		return

	time_left = maxf(time_left - delta, 0.0)
	_update_time_label()

	if time_left <= 0.0:
		_end_round()


func _update_time_label() -> void:
	time_label.text = "Tur: %d | Süre: %d sn" % [
		GameState.current_round,
		ceili(time_left)
	]


func _end_round() -> void:
	GameState.running = false
	time_label.text = "1. tur tamamlandı"
	print("1. tur tamamlandı.")

	get_tree().paused = true
	GameState.round_ended.emit()


func _on_game_lost() -> void:
	time_label.text = "Kaybettin! Kirlilik 100."
	print("Kaybettin! Kirlilik 100'e ulaştı.")
	get_tree().paused = true
