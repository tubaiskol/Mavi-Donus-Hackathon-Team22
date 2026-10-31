extends Control

@onready var start_button: Button = $CenterContainer/MenuBox/StartButton


func _ready() -> void:
	get_tree().paused = false
	GameState.running = false
	start_button.pressed.connect(_start_game)


func _start_game() -> void:
	start_button.disabled = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")
