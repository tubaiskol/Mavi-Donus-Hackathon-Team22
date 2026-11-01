extends Node2D

const FISH_SCENE := preload("res://scenes/fish.tscn")
const MAX_CONCURRENT_FISH := 4

var _spawn_timer := 0.0
var _next_interval := 3.5


func _ready() -> void:
	_next_interval = randf_range(3.0, 5.0)


func _process(delta: float) -> void:
	if not GameState.running or GameState.game_over:
		return

	_spawn_timer += delta
	if _spawn_timer >= _next_interval:
		_spawn_timer = 0.0
		_next_interval = randf_range(3.5, 6.0)
		_try_spawn_fish()


func _try_spawn_fish() -> void:
	var active_fish := get_tree().get_nodes_in_group("fish").size()
	if active_fish >= MAX_CONCURRENT_FISH:
		return

	var screen := get_viewport_rect()
	var spawn_from_left := (randf() < 0.5)
	var spawn_x := screen.position.x - 70.0 if spawn_from_left else screen.end.x + 70.0
	var min_y := maxf(screen.position.y + 170.0, get_parent().get_water_surface_y() + 80.0)
	var max_y := screen.end.y - 70.0
	if min_y > max_y:
		return
	var spawn_y := randf_range(min_y, max_y)

	var fish = FISH_SCENE.instantiate() as Area2D
	fish.direction = 1.0 if spawn_from_left else -1.0
	fish.global_position = Vector2(spawn_x, spawn_y)
	add_child(fish)


func clean_level_fish() -> void:
	for child in get_children():
		child.queue_free()
