extends CharacterBody2D

const ACCELERATION := 900.0
const FRICTION := 700.0
const EDGE_MARGIN := Vector2(24, 24)
const BASE_PICKUP_RADIUS := 40.0

const RED_BOAT_TEX := preload("res://assets/red_boat.png")
const BLUE_BOAT_TEX := preload("res://assets/blue_boat.png")

var sprite_outline := PackedVector2Array()
var pickup_polygon := ConvexPolygonShape2D.new()

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D


func _ready() -> void:
	pickup_shape.shape = pickup_polygon
	pickup_shape.transform = Transform2D.IDENTITY

	GameState.boat_changed.connect(_on_boat_changed)
	_apply_boat_texture(GameState.selected_boat)


func _on_boat_changed(boat_id: String) -> void:
	_apply_boat_texture(boat_id)


func _apply_boat_texture(boat_id: String) -> void:
	match boat_id:
		"blue":
			sprite.texture = BLUE_BOAT_TEX
			sprite.scale = Vector2(1.12, 1.12)
			sprite.self_modulate = Color.WHITE
		"emerald":
			sprite.texture = BLUE_BOAT_TEX
			sprite.scale = Vector2(1.16, 1.16)
			sprite.self_modulate = Color(0.55, 1.0, 0.72)
		"gold":
			sprite.texture = RED_BOAT_TEX
			sprite.scale = Vector2(1.08, 1.08)
			sprite.self_modulate = Color(1.0, 0.88, 0.38)
		"royal":
			sprite.texture = BLUE_BOAT_TEX
			sprite.scale = Vector2(1.22, 1.22)
			sprite.self_modulate = Color(0.86, 0.68, 1.0)
		_:
			sprite.texture = RED_BOAT_TEX
			sprite.scale = Vector2.ONE
			sprite.self_modulate = Color.WHITE

	sprite_outline = _get_sprite_outline()
	_update_pickup_shape()
	queue_redraw()


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
	# Geniş Ağ veya yeni gemi alındığında su yüzeyinde hafif toplama halkası göster.
	var extra_radius := maxf(GameState.pickup_radius - BASE_PICKUP_RADIUS, 0.0)
	if extra_radius > 0.0:
		var ring_color := Color(0.65, 0.95, 1.0, 0.28) if not GameState.has_solar else Color(0.55, 1.0, 0.78, 0.34)
		draw_arc(Vector2.ZERO, 95.0 + extra_radius, 0.0, TAU, 48, ring_color, 2.2)

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


func _get_sprite_outline() -> PackedVector2Array:
	var rect := sprite.get_rect()
	var fallback := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	])

	if sprite.texture == null:
		return fallback

	var image := sprite.texture.get_image()
	if image == null:
		return fallback

	if image.is_compressed():
		if image.decompress() != OK:
			return fallback

	# PNG'nin şeffaf boşluklarını toplama alanına katma.
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, 0.1)

	var polygons := bitmap.opaque_to_polygons(
		Rect2i(Vector2i.ZERO, image.get_size()),
		2.0
	)

	var points := PackedVector2Array()
	var image_size := Vector2(image.get_size())

	for polygon in polygons:
		for pixel in polygon:
			var uv := pixel / image_size

			if sprite.flip_h:
				uv.x = 1.0 - uv.x
			if sprite.flip_v:
				uv.y = 1.0 - uv.y

			points.append(rect.position + uv * rect.size)

	if points.size() < 3:
		return fallback

	return Geometry2D.convex_hull(points)


func _update_pickup_shape() -> void:
	# Görselin konum, boyut ve dönüşünü toplama alanına aktar.
	var relative_transform := (
		pickup_area.global_transform.affine_inverse()
		* sprite.global_transform
	)

	var points := PackedVector2Array()
	for point in sprite_outline:
		points.append(relative_transform * point)

	points = Geometry2D.convex_hull(points)

	# convex_hull son noktada ilk noktayı tekrarlar.
	if points.size() > 1:
		points.remove_at(points.size() - 1)

	# Geniş Ağ veya yeni gemi satın alındığında dış sınıra ek mesafe ekle.
	var extra_radius := maxf(
		GameState.pickup_radius - BASE_PICKUP_RADIUS,
		0.0
	)

	if extra_radius > 0.0:
		var expanded := Geometry2D.offset_polygon(
			points,
			extra_radius,
			Geometry2D.JOIN_ROUND
		)
		if not expanded.is_empty():
			points = expanded[0]

	pickup_polygon.points = points
