extends Node2D


func _ready() -> void:
	get_tree().paused = false
	GameState.reset()

	GameState.game_lost.connect(_on_game_lost)

	# Dizel motorun emisyon üretmesini başlat.
	GameState.running = true


func _on_game_lost() -> void:
	print("Kaybettin! Kirlilik 100'e ulaştı.")
	get_tree().paused = true
