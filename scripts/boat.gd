extends CharacterBody2D

const ACCELERATION := 900.0
const FRICTION := 700.0
const EDGE_MARGIN := Vector2(24, 24)
const BASE_PICKUP_RADIUS := 40.0

const BOAT_TEXTURES := {
	"red": preload("res://assets/vehicles/ship_red.png"),
	"blue": preload("res://assets/blue_boat.png"),
	"gulet": preload("res://assets/story/gulet.png"),
	"emerald": preload("res://assets/vehicles/ship_green.png"),
	"coast_guard": preload("res://assets/story/coast_guard.png"),
	"sub_fat": preload("res://assets/vehicles/sub_fat.png"),
	"sub_green": preload("res://assets/vehicles/sub_green.png"),
	"drill_robot": preload("res://assets/vehicles/drill_robot.png"),
	"gold": preload("res://assets/story/coast_guard.png"),
	"royal": preload("res://assets/vehicles/sub_fat.png")
}

var pickup_circle := CircleShape2D.new()
var _hit_flash_timer := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D


func _ready() -> void:
	pickup_shape.shape = pickup_circle
	pickup_shape.transform = Transform2D.IDENTITY

	GameState.boat_changed.connect(_on_boat_changed)
	_apply_boat_texture(GameState.selected_boat)
	_update_pickup_shape()


func _on_boat_changed(boat_id: String) -> void:
	_apply_boat_texture(boat_id)


func _apply_boat_texture(boat_id: String) -> void:
	var tex: Texture2D = BOAT_TEXTURES.get(boat_id, BOAT_TEXTURES["red"])
	sprite.texture = tex
	var longest := maxf(tex.get_width(), tex.get_height())
	var target_len := 125.0
	if boat_id in ["gulet", "coast_guard"]:
		target_len = 140.0
	elif boat_id in ["sub_fat", "drill_robot"]:
		target_len = 130.0
	elif boat_id == "blue":
		target_len = 220.0 # Orijinal blue_boat geniş şeffaf kenarlığa sahip
	var s := target_len / maxf(longest, 1.0)
	sprite.scale = Vector2(s, s)
	sprite.self_modulate = Color.WHITE

	_update_pickup_shape()
	queue_redraw()


func trigger_fish_hit_feedback() -> void:
	_hit_flash_timer = 0.8


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector(
		"move_left", "move_right",
		"move_up", "move_down"
	)

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(
			input_dir * GameState.boat_speed,
			ACCELERATION * delta
		)
	else:
		velocity = velocity.move_toward(
			Vector2.ZERO,
			FRICTION * delta
		)

	move_and_slide()

	var screen := get_viewport_rect()
	position = position.clamp(
		screen.position + EDGE_MARGIN,
		screen.end - EDGE_MARGIN
	)

	# Sol üst HUD paneli altına gemi giremez (görüş kapalı)
	if position.x < 370.0 and position.y < 162.0:
		if (370.0 - position.x) < (162.0 - position.y):
			position.x = 370.0
		else:
			position.y = 162.0

	# Teknenin ters dönmesini engelle:
	# Sağa ve sola giderken görseli yatay çevir (flip_h), asla baş aşağı dönmesin!
	if absf(velocity.x) > 12.0:
		sprite.flip_h = (velocity.x < 0.0)

	# Su üzerinde hafif meyillenme (en fazla ±10-12 derece)
	var target_tilt := 0.0
	if absf(velocity.x) > 8.0:
		var dir := -1.0 if sprite.flip_h else 1.0
		target_tilt = clampf(velocity.y / GameState.boat_speed, -1.0, 1.0) * 0.18 * dir
	else:
		target_tilt = clampf(velocity.y / GameState.boat_speed, -1.0, 1.0) * 0.10

	sprite.rotation = lerp_angle(sprite.rotation, target_tilt, 8.0 * delta)

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		var flash_phase := sin(_hit_flash_timer * 28.0)
		sprite.self_modulate = Color(1.0, 0.35, 0.35) if flash_phase > 0.0 else Color.WHITE
	else:
		sprite.self_modulate = Color.WHITE

	var is_moving := velocity.length() > 20.0

	if GameState.running and not GameState.game_over:
		if is_moving and not GameState.has_solar:
			GameState.add_pollution(GameState.emission_per_sec * delta)

	if AudioManager:
		if is_moving and GameState.running and not GameState.game_over:
			AudioManager.start_engine(GameState.has_solar)
		else:
			AudioManager.stop_engine()

	_update_pickup_shape()
	queue_redraw()


func _draw() -> void:
	# Su yüzeyindeki toplama / ağ alanını net olarak göster
	var ring_color := Color(0.65, 0.95, 1.0, 0.35) if not GameState.has_solar else Color(0.55, 1.0, 0.78, 0.40)
	draw_arc(Vector2.ZERO, GameState.pickup_radius, 0.0, TAU, 48, ring_color, 2.5)

	# Teknenin üzerinde taşınan ve konteynere götürülebilecek çöp sayısını göster
	if GameState.carried_trash > 0:
		draw_circle(Vector2(0, -48), 15.0, Color(0.08, 0.38, 0.28, 0.92))
		draw_arc(Vector2(0, -48), 15.0, 0.0, TAU, 24, Color(0.55, 1.0, 0.75), 2.0)
		var font := ThemeDB.fallback_font
		if font:
			draw_string(
				font,
				Vector2(-12, -43),
				str(GameState.carried_trash),
				HORIZONTAL_ALIGNMENT_CENTER,
				24.0,
				15,
				Color.WHITE
			)


func _update_pickup_shape() -> void:
	if pickup_circle:
		pickup_circle.radius = GameState.pickup_radius
