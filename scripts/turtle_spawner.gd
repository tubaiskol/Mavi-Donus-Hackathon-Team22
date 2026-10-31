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

	# Son 1 çöp kala veya denizdeki çöpler bittiğinde yeni kaplumbağa üretilmesin
	var spawner = get_node_or_null("../Spawner")
	if spawner and spawner.has_method("get_remaining_trash_count"):
		if spawner.get_remaining_trash_count() <= 1:
			return

	var screen := get_viewport_rect()
	var spawn_position := _get_safe_turtle_spawn_position(screen)

	turtle_instance = TURTLE_SCENE.instantiate() as Area2D

	turtle_instance.tree_exiting.connect(
		_on_turtle_removed.bind(turtle_instance, active_round)
	)

	add_child(turtle_instance)
	turtle_instance.global_position = spawn_position


func _get_safe_turtle_spawn_position(screen: Rect2) -> Vector2:
	var boat := get_node_or_null("../Boat") as Node2D
	var min_y := screen.position.y + 110.0
	var max_y := screen.end.y - EDGE_MARGIN

	for attempt in 30:
		var pos := Vector2(
			randf_range(screen.position.x + EDGE_MARGIN, screen.end.x - EDGE_MARGIN),
			randf_range(min_y, max_y)
		)
		# 1) Sol üst HUD gösterge paneli (Görüş yok)
		if pos.x < 410.0 and pos.y < 220.0:
			continue
		# 2) Sağ üst Çöp Konteyneri ve Görevler kartı bölgesi (Görüş yok)
		if pos.x > screen.end.x - 290.0 and pos.y < 350.0:
			continue
		# 3) Üst orta tur/zamanlayıcı paneli
		var center_x := screen.position.x + screen.size.x * 0.5
		if absf(pos.x - center_x) < 130.0 and pos.y < 140.0:
			continue
		if boat and pos.distance_to(boat.global_position) < 120.0:
			continue
		return pos

	# Güvenli açık deniz konumu
	return Vector2(
		randf_range(screen.position.x + 400.0, maxf(screen.position.x + 420.0, screen.end.x - 300.0)),
		randf_range(230.0, max_y)
	)


func _on_turtle_removed(turtle: Area2D, spawn_round: int) -> void:
	if turtle != turtle_instance:
		return

	turtle_instance = null

	if spawn_round != GameState.current_round:
		return

	if not GameState.running or GameState.game_over:
		return

	# Son 1 çöp kala yeni kaplumbağa üretimi için süre başlatılmasın
	var spawner = get_node_or_null("../Spawner")
	if spawner and spawner.has_method("get_remaining_trash_count"):
		if spawner.get_remaining_trash_count() <= 1:
			return

	# Yalnızca kurtarıldıysa yeni üretim için süre başlat.
	if turtle.get("rescued") == true:
		spawn_timer.start(RESPAWN_DELAY)
