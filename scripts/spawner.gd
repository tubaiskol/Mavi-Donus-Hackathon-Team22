extends Node2D

const TRASH_SCENE := preload("res://scenes/trash.tscn")
const MAX_TRASH := 15
const SPAWN_MARGIN := 48.0

@onready var spawn_timer: Timer = $Timer


func _ready() -> void:
	spawn_timer.timeout.connect(_spawn_trash)


func _spawn_trash() -> void:
	if GameState.game_over:
		return

	if get_tree().get_nodes_in_group("trash").size() >= MAX_TRASH:
		return

	var screen := get_viewport_rect()
	var spawn_position := Vector2(
		randf_range(
			screen.position.x + SPAWN_MARGIN,
			screen.end.x - SPAWN_MARGIN
		),
		randf_range(
			screen.position.y + SPAWN_MARGIN,
			screen.end.y - SPAWN_MARGIN
		)
	)

	var trash := TRASH_SCENE.instantiate() as Area2D
	trash.add_to_group("trash")
	add_child(trash)
	trash.global_position = spawn_position
