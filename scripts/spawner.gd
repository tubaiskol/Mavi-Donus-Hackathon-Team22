extends Node2D

const TRASH_SCENE := preload("res://scenes/trash.tscn")
const TOTAL_TRASH := 15
const MAX_VISIBLE_TRASH := 15
const SPAWN_MARGIN := 48.0

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
	spawn_timer.start()


func _spawn_trash() -> void:
	if GameState.game_over or not GameState.running:
		return

	if spawned_total >= TOTAL_TRASH:
		spawn_timer.stop()
		return

	if _get_active_trash_count() >= MAX_VISIBLE_TRASH:
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

	spawned_total += 1

	if spawned_total >= TOTAL_TRASH:
		spawn_timer.stop()
		print("Bu seviyenin tüm çöpleri üretildi. Toplam: ", TOTAL_TRASH)


func get_remaining_trash_count() -> int:
	# Kalan = henüz üretilmeyenler + toplanmamış nesneler.
	return TOTAL_TRASH - spawned_total + _get_active_trash_count()


func _get_active_trash_count() -> int:
	var count := 0

	for trash in get_tree().get_nodes_in_group("trash"):
		if trash.is_queued_for_deletion():
			continue

		if trash.get("collected"):
			continue

		count += 1

	return count
