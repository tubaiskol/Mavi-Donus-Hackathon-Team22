extends Node2D

const TRASH_SCENE := preload("res://scenes/trash.tscn")
const MAX_VISIBLE_TRASH := 15
const SPAWN_MARGIN := 48.0

var total_trash := 15
var TOTAL_TRASH: int:
	get:
		return total_trash

var initial_spawn_count := 5
var spawned_total := 0
var active_round := 0

@onready var spawn_timer: Timer = $Timer


func _ready() -> void:
	spawn_timer.timeout.connect(_spawn_trash)
	start_level()


func _process(_delta: float) -> void:
	# Seviye değişince üretim hakkını yenile.
	if GameState.running and active_round != GameState.current_round:
		start_level()


func start_level() -> void:
	# Önceki seviyeye ait nesneleri temizle.
	for child in get_children():
		if child.is_in_group("trash"):
			child.queue_free()

	active_round = GameState.current_round
	spawned_total = 0

	# Seviyeye göre zorluk parametreleri
	total_trash = _get_trash_count_for_level(active_round)
	initial_spawn_count = _get_initial_trash_for_level(active_round)
	spawn_timer.wait_time = _get_spawn_interval_for_level(active_round)

	# Seviye başladığında denizde hemen rastgele çöpler bulunsun.
	var initial_count := mini(initial_spawn_count, total_trash)
	for i in initial_count:
		_spawn_single_trash()

	if spawned_total < total_trash:
		spawn_timer.start()


func _get_trash_count_for_level(level: int) -> int:
	match level:
		1: return 15
		2: return 18
		3: return 20
		4: return 23
		_: return 25


func _get_initial_trash_for_level(level: int) -> int:
	match level:
		1: return 5
		2: return 6
		3: return 7
		4: return 8
		_: return 8


func _get_spawn_interval_for_level(level: int) -> float:
	match level:
		1: return 2.2
		2: return 1.9
		3: return 1.7
		4: return 1.5
		_: return 1.3


func _spawn_trash() -> void:
	if GameState.game_over or not GameState.running:
		return

	if spawned_total >= total_trash:
		spawn_timer.stop()
		return

	if _get_active_trash_count() >= MAX_VISIBLE_TRASH:
		return

	_spawn_single_trash()


func _spawn_single_trash() -> void:
	if spawned_total >= total_trash:
		spawn_timer.stop()
		return

	var spawn_position := _get_random_spawn_position()

	var trash := TRASH_SCENE.instantiate() as Area2D
	trash.add_to_group("trash")
	add_child(trash)
	trash.global_position = spawn_position

	spawned_total += 1

	if spawned_total >= total_trash:
		spawn_timer.stop()
		print("Seviye %d tüm çöpleri üretildi. Toplam: %d" % [active_round, total_trash])


func _get_random_spawn_position() -> Vector2:
	var screen := get_viewport_rect()
	var boat := get_node_or_null("../Boat") as Node2D

	for attempt in 10:
		var pos := Vector2(
			randf_range(
				screen.position.x + SPAWN_MARGIN,
				screen.end.x - SPAWN_MARGIN
			),
			randf_range(
				screen.position.y + SPAWN_MARGIN,
				screen.end.y - SPAWN_MARGIN
			)
		)
		if boat and pos.distance_to(boat.global_position) < 90.0:
			continue
		return pos

	return Vector2(
		randf_range(
			screen.position.x + SPAWN_MARGIN,
			screen.end.x - SPAWN_MARGIN
		),
		randf_range(
			screen.position.y + SPAWN_MARGIN,
			screen.end.y - SPAWN_MARGIN
		)
	)


func get_remaining_trash_count() -> int:
	# Kalan = henüz üretilmeyenler + toplanmamış nesneler.
	return total_trash - spawned_total + _get_active_trash_count()


func _get_active_trash_count() -> int:
	var count := 0

	for trash in get_tree().get_nodes_in_group("trash"):
		if trash.is_queued_for_deletion():
			continue

		if trash.get("collected"):
			continue

		count += 1

	return count
