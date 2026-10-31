extends Node2D

const TURTLE_SCENE := preload("res://scenes/turtle.tscn")
const FIRST_SPAWN_DELAY := 4.0
const RESPAWN_DELAY := 15.0
const EDGE_MARGIN := 64.0

var active_round := 0
var turtle_instance: Area2D

@onready var spawn_timer: Timer = $Timer


func _ready() -> void:
	spawn_timer.stop()
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_spawn_turtle)


func _process(_delta: float) -> void:
	if not GameState.running or GameState.game_over:
		return

	if active_round == GameState.current_round:
		return

	active_round = GameState.current_round
	spawn_timer.stop()

	if is_instance_valid(turtle_instance):
		turtle_instance.queue_free()

	turtle_instance = null

	# Her yeni seviyede ilk caretta için 4 saniye bekle.
	if active_round >= 2:
		spawn_timer.start(FIRST_SPAWN_DELAY)


func _spawn_turtle() -> void:
	if not GameState.running or GameState.game_over:
		return

	if GameState.current_round < 2:
		return

	if is_instance_valid(turtle_instance):
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

	turtle_instance = TURTLE_SCENE.instantiate() as Area2D

	turtle_instance.tree_exiting.connect(
		_on_turtle_removed.bind(turtle_instance, active_round)
	)

	add_child(turtle_instance)
	turtle_instance.global_position = spawn_position


func _on_turtle_removed(turtle: Area2D, spawn_round: int) -> void:
	if turtle != turtle_instance:
		return

	turtle_instance = null

	if spawn_round != GameState.current_round:
		return

	if not GameState.running or GameState.game_over:
		return

	# Yalnızca kurtarıldıysa yeni üretim için süre başlat.
	if turtle.get("rescued") == true:
		spawn_timer.start(RESPAWN_DELAY)
