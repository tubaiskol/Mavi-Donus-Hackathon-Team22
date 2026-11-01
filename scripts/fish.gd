extends Area2D

# NOT: fish_grey_long_a.png ve fish_grey_long_b.png aynı yılan balığının iki YARIM parçası
# (biri baş, biri gövde). Tek balık olarak kullanılınca yarım görünüyordu; bunun yerine
# tam olan fish_grey.png kullanılıyor.
const FISH_TEXTURES := [
	preload("res://assets/fish/fish_blue.png"),
	preload("res://assets/fish/fish_orange.png"),
	preload("res://assets/fish/fish_green.png"),
	preload("res://assets/fish/fish_pink.png"),
	preload("res://assets/fish/fish_red.png"),
	preload("res://assets/fish/fish_brown.png"),
	preload("res://assets/fish/fish_grey.png")
]

const SKELETON_TEXTURES := [
	preload("res://assets/fish/fish_blue_skeleton.png"),
	preload("res://assets/fish/fish_orange_skeleton.png"),
	preload("res://assets/fish/fish_green_skeleton.png"),
	preload("res://assets/fish/fish_pink_skeleton.png"),
	preload("res://assets/fish/fish_red_skeleton.png")
]

const SCHOOL_TEXTURE := preload("res://assets/fish/fish_school.png")

# Balık, geminin GÖVDESİNE bu mesafeden yaklaşınca çarpmış sayılır.
# (Eskiden geminin toplama halkasına değmesi yetiyordu; Geniş Ağ / büyük araç aldıkça
# halka büyüdüğü için balıklara uzaktan çarpılıyordu.)
const BOAT_HIT_RADIUS := 42.0
const MAX_TILT := 0.35 # radyan (~20 derece)
const TOP_MARGIN := 150.0
const BOTTOM_MARGIN := 50.0

var speed := 90.0
var direction := 1.0 # 1.0: soldan sağa, -1.0: sağdan sola
var swim_freq := 2.0 # rad/sn
var swim_amp := 20.0 # piksel (yukarı-aşağı salınım genliği)
var base_y := 0.0
var hit_radius := 22.0
var _time := 0.0
var _escape_y := 1.0
var is_hit := false
var is_school := false
var _boat: Node2D

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_time = randf() * TAU
	speed = randf_range(80.0, 130.0)
	swim_freq = randf_range(1.6, 2.6)
	swim_amp = randf_range(14.0, 28.0)

	# Dalga, ekranın üst HUD alanına ya da alt kenara taşmasın.
	var screen := get_viewport_rect()
	base_y = clampf(
		global_position.y,
		screen.position.y + TOP_MARGIN + swim_amp,
		screen.end.y - BOTTOM_MARGIN - swim_amp
	)

	var scene_root := get_tree().current_scene
	if scene_root:
		_boat = scene_root.get_node_or_null("Boat") as Node2D

	_setup_visual()


func _setup_visual() -> void:
	# %20 ihtimalle balık sürüsü, geri kalanı tekli balıklar
	is_school = (randf() < 0.20)

	if is_school and SCHOOL_TEXTURE:
		sprite.texture = SCHOOL_TEXTURE
		sprite.scale = Vector2(0.40, 0.40)
	elif GameState.pollution >= 75.0 and not SKELETON_TEXTURES.is_empty() and randf() < 0.60:
		# Kirlilik kritik seviyedeyken iskelet balıklar belirir
		sprite.texture = SKELETON_TEXTURES.pick_random()
		sprite.scale = Vector2(0.55, 0.55)
	else:
		sprite.texture = FISH_TEXTURES.pick_random()
		sprite.scale = Vector2(0.55, 0.55)

	# Tüm balık görselleri SAĞA bakar; sağdan gelenleri yatay çevir.
	sprite.flip_h = (direction < 0.0)

	# Çarpma yarıçapı balığın gerçek boyutundan hesaplanır (sürü büyük, tekli küçük).
	var shown := sprite.texture.get_size() * sprite.scale
	if is_school:
		hit_radius = clampf(minf(shown.x, shown.y) * 0.5, 14.0, 60.0)
	else:
		hit_radius = clampf(shown.x * 0.30, 14.0, 34.0)


func _physics_process(delta: float) -> void:
	_time += delta

	if is_hit:
		# Çarpışma sonrası: yönünde hızlanıp gemiden uzaklaşarak kaybolur
		global_position.x += direction * speed * 1.8 * delta
		global_position.y += _escape_y * 110.0 * delta
		rotation = lerp_angle(rotation, 0.0, 6.0 * delta)
		modulate.a = maxf(modulate.a - delta * 1.5, 0.0)
		if modulate.a <= 0.01:
			queue_free()
		return

	# Düz ilerleme + yumuşak sinüs yüzüşü.
	# Y konumu doğrudan hesaplanır (sürekli toplama yerine), böylece dalga yerinde kalır.
	global_position.x += direction * speed * delta
	global_position.y = base_y + sin(_time * swim_freq) * swim_amp

	# Burun, dikey hıza doğru hafifçe eğilir (balık yüzerken yamulmuş gibi kaymaz).
	var vy := cos(_time * swim_freq) * swim_amp * swim_freq
	var tilt := clampf(atan2(vy, speed), -MAX_TILT, MAX_TILT)
	rotation = tilt * direction * (0.5 if is_school else 1.0)

	_check_boat_hit()

	var screen := get_viewport_rect()
	if direction > 0.0 and global_position.x > screen.end.x + 120.0:
		queue_free()
	elif direction < 0.0 and global_position.x < screen.position.x - 120.0:
		queue_free()


func _check_boat_hit() -> void:
	if is_hit or not GameState.running or GameState.game_over:
		return
	if _boat == null or not is_instance_valid(_boat):
		return
	# Tekne yanıp sönerken (iyileşme süresi) ikinci bir ceza verilmez.
	if _boat.has_method("is_invulnerable") and _boat.is_invulnerable():
		return
	if global_position.distance_to(_boat.global_position) > BOAT_HIT_RADIUS + hit_radius:
		return

	is_hit = true
	_escape_y = 1.0 if global_position.y >= _boat.global_position.y else -1.0

	# GDD Madde 5.5: Balığa çarpınca kirlilik artar ve tekne yanıp söner
	GameState.add_pollution(GameState.fish_penalty)

	if AudioManager:
		AudioManager.play_fish_hit()

	if _boat.has_method("trigger_fish_hit_feedback"):
		_boat.trigger_fish_hit_feedback()

	GameState.show_toast(
		"⚠️ Dikkat! Balıklara çarpmamaya çalış! Deniz yaşamı etkilendi (+%.0f Kirlilik)" % GameState.fish_penalty,
		2.5
	)
