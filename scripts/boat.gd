extends CharacterBody2D

const ACCELERATION := 900.0   # hızlanma
const FRICTION := 700.0       # yavaşlama
const EDGE_MARGIN := Vector2(24, 24)  # ekran kenarından boşluk

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D


func _ready() -> void:
	_update_pickup_radius()


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * GameState.boat_speed, ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	move_and_slide()

	# Ekran sınırları dışına çıkma
	var screen := get_viewport_rect()
	position = position.clamp(screen.position + EDGE_MARGIN, screen.end - EDGE_MARGIN)

	# Hareket yönüne doğru yumuşak dönüş (sprite sağa bakıyorsa)
	if velocity.length() > 10.0:
		sprite.rotation = lerp_angle(sprite.rotation, velocity.angle(), 10.0 * delta)

	_update_pickup_radius()


func _update_pickup_radius() -> void:
	var circle := pickup_shape.shape as CircleShape2D
	if circle and not is_equal_approx(circle.radius, GameState.pickup_radius):
		circle.radius = GameState.pickup_radius
