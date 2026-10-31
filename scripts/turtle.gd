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
	hide()
	rescue_bar.min_value = 0.0
	rescue_bar.max_value = RESCUE_DURATION
	rescue_bar.value = 0.0
	rescue_bar.hide()

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
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
	rescue_bar.value = rescue_time

	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		_pulse_timer = 0.55
		if AudioManager:
			AudioManager.play_turtle_pulse()

	if rescue_time >= RESCUE_DURATION:
		_rescue()


func _draw() -> void:
	if sprite and sprite.texture == null:
		var offset_y := sin(_bob_t) * 2.0
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
			draw_line(Vector2(-34, i * 14), Vector2(34, i * 14), net, 2.0)
			draw_line(Vector2(i * 14, -34), Vector2(i * 14, 34), net, 2.0)
		var progress := clampf(rescue_time / RESCUE_DURATION, 0.0, 1.0)
		if progress > 0.01:
			draw_arc(
				Vector2.ZERO,
				42.0,
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
	rescue_bar.show()


func _on_area_exited(area: Area2D) -> void:
	if rescued or area.name != &"PickupArea":
		return

	boat_near = false
	rescue_time = 0.0
	rescue_bar.value = 0.0
	rescue_bar.hide()
	queue_redraw()


func _rescue() -> void:
	rescued = true
	rescue_bar.hide()

	if AudioManager:
		AudioManager.play_turtle()

	GameState.add_coins(RESCUE_REWARD)
	GameState.add_pollution(GameState.turtle_value)
	GameState.record_turtle_rescue()
	GameState.show_toast("Caretta kurtarıldı! +%d Coin | %.0f Kirlilik" % [RESCUE_REWARD, GameState.turtle_value], 2.8)

	print("Caretta kurtarıldı! +5 coin")
	queue_free()
