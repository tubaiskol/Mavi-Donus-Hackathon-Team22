extends Node2D

const TRASH_SCENE := preload("res://scenes/trash.tscn")
const MAX_VISIBLE_TRASH := 15
const SPAWN_MARGIN := 64.0
const TOP_HUD_MARGIN := 108.0

var total_trash := 15
var TOTAL_TRASH: int:
	get:
		return total_trash

var initial_spawn_count := 7
var spawned_total := 0
var active_round := 0

@onready var spawn_timer: Timer = $Timer


func _ready() -> void:
	spawn_timer.timeout.connect(_spawn_trash)


func _process(_delta: float) -> void:
	# Seviye değişince üretim hakkını yenile.
	if GameState.running and active_round != GameState.current_round:
		start_level()


func start_level() -> void:
	spawn_timer.stop()

	# Önceki seviyeye ait nesneleri temizle.
	for child in get_children():
		if child.is_in_group("trash"):
			child.remove_from_group("trash")
			child.queue_free()

	active_round = GameState.current_round
	spawned_total = 0

	# Seviyeye göre zorluk parametreleri
	total_trash = _get_trash_count_for_level(active_round)
	initial_spawn_count = _get_initial_trash_for_level(active_round)
	spawn_timer.wait_time = _get_spawn_interval_for_level(active_round)

	# Başlangıç kirliliğini (en az %50) başlangıçtaki 7-8 çöple tutarlı başlat.
	var initial_count := mini(initial_spawn_count, total_trash)
	GameState.start_level_pollution(total_trash, initial_count)

	# Seviye başladığında denizde hemen 7-8 varsayılan çöp bulunsun.
	for i in initial_count:
		_spawn_single_trash(true)

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
	# Oyun ve seviyeler başlarken denizde 7-8 varsayılan çöp bulunur.
	match level:
		1: return 7
		2: return 7
		3: return 8
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

	# Sonradan spawn olan çöpler kirliliği artırır (is_initial_trash = false).
	_spawn_single_trash(false)


func _spawn_single_trash(is_initial: bool = false) -> void:
	if spawned_total >= total_trash:
		spawn_timer.stop()
		return

	var spawn_position := _get_random_spawn_position()
	if not spawn_position.is_finite():
		return

	var trash := TRASH_SCENE.instantiate() as Area2D
	trash.set("is_initial_trash", is_initial)
	trash.add_to_group("trash")
	trash.global_position = spawn_position
	add_child(trash)

	spawned_total += 1

	if spawned_total >= total_trash:
		spawn_timer.stop()
		print("Seviye %d tüm çöpleri üretildi. Toplam: %d" % [active_round, total_trash])


func _get_random_spawn_position() -> Vector2:
	var screen := get_viewport_rect()
	var boat := get_node_or_null("../Boat") as Node2D
	var min_y := maxf(screen.position.y + TOP_HUD_MARGIN, get_parent().get_water_surface_y() + 32.0)
	var max_y := screen.end.y - SPAWN_MARGIN
	if min_y > max_y:
		return Vector2.INF

	for attempt in 30:
		var pos := Vector2(
			randf_range(
				screen.position.x + SPAWN_MARGIN,
				screen.end.x - SPAWN_MARGIN
			),
			randf_range(min_y, max_y)
		)
		if _is_position_in_forbidden_zone(pos, screen):
			continue
		if boat and pos.distance_to(boat.global_position) < 90.0:
			continue
		return pos

	# Rastgele denemeler tükenince de aynı yasak alan denetimi uygulanır.
	for y in range(ceili(min_y), int(max_y) + 1, 32):
		for x in range(int(screen.position.x + SPAWN_MARGIN), int(screen.end.x - SPAWN_MARGIN) + 1, 32):
			var pos := Vector2(x, y)
			if not _is_position_in_forbidden_zone(pos, screen) and (boat == null or pos.distance_to(boat.global_position) >= 90.0):
				return pos
	return Vector2.INF


func _is_position_in_forbidden_zone(pos: Vector2, screen: Rect2) -> bool:
	# 1) Sol üst HUD gösterge paneli (Kirlilik, sayaç ve istatistik kartı)
	if get_parent().get_node("HUD").get_stats_panel_rect().grow(32.0).has_point(pos):
		return true
	# 2) Sağ alt paneller: görsel boyutu ve yanaşma payı da boş kalır.
	if get_parent().get_reserved_panels_rect().grow(64.0).has_point(pos):
		return true
	# 3) Üst orta Tur / Zamanlayıcı / Duraklat paneli
	var center_x := screen.position.x + screen.size.x * 0.5
	if absf(pos.x - center_x) < 130.0 and pos.y < 140.0:
		return true
	return false


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
