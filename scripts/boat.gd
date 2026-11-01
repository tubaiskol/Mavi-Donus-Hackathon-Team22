extends CharacterBody2D

const ACCELERATION := 900.0
const FRICTION := 700.0
const BASE_PICKUP_RADIUS := 40.0

# Görsellerin varsayılan baktığı yön. Burada yazmayan araçlar SAĞA bakar.
# Kırmızı ve yeşil gemi görselleri SOLA bakıyor (başı solda), diğerleri sağa.
const FACES_LEFT := ["red", "emerald"]

const BOAT_TEXTURES := {
	"red": preload("res://assets/vehicles/ship_red.png"),
	"blue": preload("res://assets/blue_boat.png"),
	"gulet": preload("res://assets/story/gulet.png"),
	"emerald": preload("res://assets/vehicles/ship_green.png"),
	"coast_guard": preload("res://assets/story/coast_guard.png"),
	"sub_fat": preload("res://assets/vehicles/sub_fat.png"),
	"sub_green": preload("res://assets/vehicles/sub_green.png"),
	"gold": preload("res://assets/story/coast_guard.png"),
	"royal": preload("res://assets/vehicles/sub_fat.png")
}

var pickup_circle := CircleShape2D.new()
var _hit_flash_timer := 0.0
var _sprite_faces_left := false
var _look_dir := 1.0 # son yatay yön: -1 sol, +1 sağ
var _edge_margin := Vector2(24, 24)
var _hull_shape := RectangleShape2D.new()

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D


func _ready() -> void:
	$CollisionShape2D.shape = _hull_shape
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
	elif boat_id == "sub_fat":
		target_len = 130.0
	var s := target_len / maxf(longest, 1.0)
	sprite.scale = Vector2(s, s)
	sprite.self_modulate = Color.WHITE

	# Her aracın görseli farklı yöne bakabilir; çevirme buna göre yapılır.
	var resolved_id: String = boat_id
	if boat_id == "gold":
		resolved_id = "coast_guard"
	elif boat_id == "royal":
		resolved_id = "sub_fat"
	_sprite_faces_left = resolved_id in FACES_LEFT

	# Ekran kenar payı gemi boyuna göre (eski sabit 24 px gemiyi yarı ekran dışına çıkarıyordu).
	var shown := tex.get_size() * s
	_edge_margin = Vector2(maxf(shown.x * 0.45, 24.0), maxf(shown.y * 0.40, 24.0))
	# Görselin tamamı (su üzerindeki eğim dahil) panellerin dışında kalsın.
	_hull_shape.size = Vector2(shown.x + shown.y * sin(0.18), shown.y + shown.x * sin(0.18))

	_update_pickup_shape()
	queue_redraw()


func trigger_fish_hit_feedback() -> void:
	_hit_flash_timer = 0.8


# Tekne yanıp sönerken (balığa çarptıktan sonra) tekrar ceza yemez.
func is_invulnerable() -> bool:
	return _hit_flash_timer > 0.0


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

	enforce_water_bounds()

	# İstatistik kartı büyüse de teknenin görseli panelin dışında kalır.
	var stats_rect: Rect2 = get_parent().get_node("HUD").get_stats_panel_rect()
	stats_rect = stats_rect.grow_individual(_hull_shape.size.x * 0.5, _hull_shape.size.y * 0.5, _hull_shape.size.x * 0.5, _hull_shape.size.y * 0.5)
	if stats_rect.has_point(position):
		if (stats_rect.end.x - position.x) < (stats_rect.end.y - position.y):
			position.x = stats_rect.end.x
			velocity.x = 0.0
		else:
			position.y = stats_rect.end.y
			velocity.y = 0.0

	# Teknenin ters dönmesini engelle:
	# Sağa/sola giderken görseli yatay çevir (flip_h); asla baş aşağı dönmez.
	# Görsel sola bakıyorsa (kırmızı, yeşil gemi) çevirme mantığı tersine işler.
	if absf(velocity.x) > 12.0:
		_look_dir = signf(velocity.x)
	sprite.flip_h = ((_look_dir < 0.0) != _sprite_faces_left)

	# Su üzerinde hafif meyillenme (en fazla ±10 derece), baş gidilen yöne göre
	var target_tilt := clampf(velocity.y / maxf(GameState.boat_speed, 1.0), -1.0, 1.0) * 0.18 * _look_dir

	sprite.rotation = lerp_angle(sprite.rotation, target_tilt, 8.0 * delta)
	enforce_water_bounds()

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		var flash_phase := sin(_hit_flash_timer * 28.0)
		sprite.self_modulate = Color(1.0, 0.35, 0.35) if flash_phase > 0.0 else Color.WHITE
	else:
		sprite.self_modulate = Color.WHITE

	var is_moving := velocity.length() > 20.0

	if GameState.running and not GameState.game_over:
		if is_moving and GameState.get_current_emission_rate() > 0.0:
			GameState.add_pollution(GameState.get_current_emission_rate() * delta)

	if AudioManager:
		if is_moving and GameState.running and not GameState.game_over:
			AudioManager.start_engine(GameState.has_solar)
		else:
			AudioManager.stop_engine()

	_update_pickup_shape()
	queue_redraw()





func enforce_water_bounds() -> void:
	var screen := get_viewport_rect()
	var min_y := screen.position.y + _edge_margin.y
	position = position.clamp(Vector2(screen.position.x + _edge_margin.x, min_y), screen.end - _edge_margin)
	if position.y <= min_y and velocity.y < 0.0:
		velocity.y = 0.0


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
