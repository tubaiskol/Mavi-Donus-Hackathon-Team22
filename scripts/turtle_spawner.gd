extends Node2D

const TURTLE_SCENE := preload("res://scenes/turtle.tscn")
const EDGE_MARGIN := 64.0

var active_round := 0

@onready var spawn_timer: Timer = $Timer


func _ready() -> void:
	spawn_timer.timeout.connect(_spawn_turtle)


func _process(_delta: float) -> void:
	if not GameState.running or GameState.game_over:
		return

	if active_round == GameState.current_round:
		return

	active_round = GameState.current_round
	spawn_timer.stop()

	# Önceki seviyeden kalan carettayı temizle.
	for child in get_children():
		if child is Area2D:
			child.queue_free()

	if active_round >= 2:
		_spawn_turtle()
		spawn_timer.start()


func _spawn_turtle() -> void:
	if not GameState.running or GameState.game_over:
		return

	if GameState.current_round < 2:
		return

	# Mevcut caretta kurtarılmadıysa yenisini üretme.
	for child in get_children():
		if child is Area2D and not child.is_queued_for_deletion():
			return

	var screen := get_viewport_rect()
	var spawn_position := Vector2(
		randf_range(
			screen.position.x + EDGE_MARGIN,
			screen.end.x - EDGE_MARGIN
		),
		randf_range(
			screen.position.y + EDGE_MARGIN,
			screen.end.y - EDGE_MARGIN
		)
	)

	var turtle := TURTLE_SCENE.instantiate() as Area2D
	add_child(turtle)
	turtle.global_position = spawn_position
