extends CharacterBody2D

const ACCELERATION := 900.0
const FRICTION := 700.0
const EDGE_MARGIN := Vector2(24, 24)
const BASE_PICKUP_RADIUS := 40.0

var sprite_outline := PackedVector2Array()
var pickup_polygon := ConvexPolygonShape2D.new()

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D


func _ready() -> void:
	sprite_outline = _get_sprite_outline()

	# Her teknenin kendine ait toplama şekli olsun.
	pickup_shape.shape = pickup_polygon
	pickup_shape.transform = Transform2D.IDENTITY
	_update_pickup_shape()


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

	if velocity.length() > 10.0:
		sprite.rotation = lerp_angle(
			sprite.rotation,
			velocity.angle(),
			10.0 * delta
		)

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

	# Geniş Ağ satın alındığında dış sınıra ek mesafe ekle.
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
