extends Area2D

const RESCUE_DURATION := 2.0
const RESCUE_REWARD := 5

var boat_near := false
var rescue_time := 0.0
var rescued := false
var _bob_t := 0.0
var _pulse_timer := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var rescue_bar: ProgressBar = $RescueBar


func _ready() -> void:
	_bob_t = randf() * TAU
	enforce_water_bounds()
	hide()
	# Çift progress bar karmaşasını önlemek için alttaki dikdörtgen bar gizlenir,
	# yerine kaplumbağanın etrafını saran dairesel altın kurtarma halkası kullanılır.
	if rescue_bar:
		rescue_bar.hide()

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	enforce_water_bounds()
	if rescued:
		return

	# İlk seviyede caretta görünmez ve kurtarma ilerlemez.
	if GameState.current_round < 2:
		hide()
		return

	show()
	_bob_t += delta * 2.0
	queue_redraw()

	if not GameState.running or GameState.game_over:
		return

	if not boat_near:
		return

	rescue_time = minf(rescue_time + delta, RESCUE_DURATION)

	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		_pulse_timer = 0.55
		if AudioManager:
			AudioManager.play_turtle_pulse()

	if rescue_time >= RESCUE_DURATION:
		_rescue()


func enforce_water_bounds() -> void:
	var game := get_parent().get_parent()
	if game.has_water_surface():
		global_position.y = maxf(global_position.y, game.get_water_surface_y() + 50.0)


func _draw() -> void:
	var offset_y := sin(_bob_t) * 2.0

	if sprite and sprite.texture == null:
		var skin := Color(0.42, 0.72, 0.50)
		for s in [-1, 1]:
			draw_circle(Vector2(10, s * 22 + offset_y), 9.0, skin)
			draw_circle(Vector2(-14, s * 18 + offset_y), 7.0, skin)
		draw_circle(Vector2(0, offset_y), 22.0, Color(0.52, 0.38, 0.26))
		draw_circle(Vector2(0, offset_y), 14.0, Color(0.68, 0.52, 0.36))
		draw_circle(Vector2(26, offset_y), 9.0, skin)

	if not rescued:
		var net := Color(0.22, 0.26, 0.30, 0.72)
		for i in range(-2, 3):
			draw_line(Vector2(-34, i * 14 + offset_y), Vector2(34, i * 14 + offset_y), net, 2.0)
			draw_line(Vector2(i * 14, -34 + offset_y), Vector2(i * 14, 34 + offset_y), net, 2.0)

		# Tek ve şık kurtarma göstergesi: altın dolum halkası
		var progress := clampf(rescue_time / RESCUE_DURATION, 0.0, 1.0)
		if boat_near or progress > 0.01:
			draw_arc(
				Vector2(0, offset_y),
				44.0,
				0.0,
				TAU,
				36,
				Color(0.2, 0.2, 0.2, 0.35),
				4.0
			)
			if progress > 0.01:
				draw_arc(
					Vector2(0, offset_y),
					44.0,
					-PI / 2.0,
					-PI / 2.0 + TAU * progress,
					40,
					Color(1.0, 0.86, 0.22),
					5.0
				)


func _on_area_entered(area: Area2D) -> void:
	if rescued or area.name != &"PickupArea":
		return

	boat_near = true
	_pulse_timer = 0.0


func _on_area_exited(area: Area2D) -> void:
	if rescued or area.name != &"PickupArea":
		return

	boat_near = false
	rescue_time = 0.0
	queue_redraw()


func _rescue() -> void:
	rescued = true

	if AudioManager:
		AudioManager.play_turtle()

	GameState.add_coins(RESCUE_REWARD)
	GameState.add_pollution(GameState.turtle_value)
	GameState.record_turtle_rescue()
	GameState.show_toast("Caretta kurtarıldı! +%d Coin | %.0f Kirlilik" % [RESCUE_REWARD, GameState.turtle_value], 2.8)

	print("Caretta kurtarıldı! +5 coin")
	queue_free()
