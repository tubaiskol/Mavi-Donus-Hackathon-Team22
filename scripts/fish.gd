extends Area2D

const FISH_TEXTURES := [
	preload("res://assets/fish/fish_blue.png"),
	preload("res://assets/fish/fish_orange.png"),
	preload("res://assets/fish/fish_green.png"),
	preload("res://assets/fish/fish_pink.png"),
	preload("res://assets/fish/fish_red.png"),
	preload("res://assets/fish/fish_brown.png"),
	preload("res://assets/fish/fish_grey_long_a.png"),
	preload("res://assets/fish/fish_grey_long_b.png")
]

const SKELETON_TEXTURES := [
	preload("res://assets/fish/fish_blue_skeleton.png"),
	preload("res://assets/fish/fish_orange_skeleton.png"),
	preload("res://assets/fish/fish_green_skeleton.png"),
	preload("res://assets/fish/fish_pink_skeleton.png"),
	preload("res://assets/fish/fish_red_skeleton.png")
]

const SCHOOL_TEXTURE := preload("res://assets/fish/fish_school.png")

var speed := 90.0
var direction := 1.0 # 1.0: soldan sağa, -1.0: sağdan sola
var swim_freq := 3.0
var swim_amp := 18.0
var _time := 0.0
var is_hit := false
var is_school := false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_time = randf() * TAU
	speed = randf_range(80.0, 130.0)
	swim_freq = randf_range(2.5, 4.0)
	swim_amp = randf_range(12.0, 24.0)

	_setup_visual()
	area_entered.connect(_on_area_entered)


func _setup_visual() -> void:
	# %20 ihtimalle 6'lı balık sürüsü, geri kalan tekli canlı balıklar
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

	# Yüzme yönüne göre yatay çevir (Orijinal balıklar sağa bakar)
	sprite.flip_h = (direction < 0.0)


func _physics_process(delta: float) -> void:
	_time += delta

	if is_hit:
		# Çarpışma sonrası hızla kaçış
		position.x += direction * speed * 2.2 * delta
		position.y += sin(_time * 6.0) * 35.0 * delta
		modulate.a = maxf(modulate.a - delta * 1.5, 0.0)
		if modulate.a <= 0.01:
			queue_free()
		return

	position.x += direction * speed * delta
	position.y += sin(_time * swim_freq) * (swim_amp * delta)

	var screen := get_viewport_rect()
	if direction > 0.0 and position.x > screen.end.x + 120.0:
		queue_free()
	elif direction < 0.0 and position.x < screen.position.x - 120.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if is_hit or not GameState.running or GameState.game_over:
		return

	if area.name != &"PickupArea":
		return

	is_hit = true

	# GDD Madde 5.5: Balığa çarpınca kirlilik artar (ceza: +5.0) ve tekne yanıp söner
	GameState.add_pollution(GameState.fish_penalty)

	if AudioManager:
		AudioManager.play_fish_hit()

	var boat := area.get_parent()
	if boat and boat.has_method("trigger_fish_hit_feedback"):
		boat.trigger_fish_hit_feedback()

	GameState.show_toast(
		"⚠️ Dikkat! Balıklara çarpmamaya çalış! Deniz yaşamı etkilendi (+%.0f Kirlilik)" % GameState.fish_penalty,
		2.5
	)
