extends Area2D

@export var is_initial_trash := true
@export var trash_textures: Array[Texture2D] = []

@onready var trash_sprite: Sprite2D = $Sprite2D

var trash_name := "Çöp"
var coin_reward := 1
var pollution_reduction := 3.5
var own_pollution := 3.5
var collected := false
var _bob_phase := 0.0
var _base_sprite_pos := Vector2.ZERO
var _surface_clearance := 32.0


func _ready() -> void:
	_bob_phase = randf() * TAU
	_base_sprite_pos = trash_sprite.position
	_apply_random_texture()
	enforce_water_bounds()

	if is_initial_trash:
		# Başlangıçtaki 7-8 çöp, başlangıç (%50+) kirliliğine zaten dahildir.
		own_pollution = GameState.get_initial_trash_unit_pollution()
	else:
		# Oyun sırasında yeni spawn olan çöpler denizin kirliliğini artırır!
		own_pollution = pollution_reduction
		GameState.add_new_trash_pollution(own_pollution)

	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	enforce_water_bounds()
	if not GameState.running or GameState.game_over:
		return
	_bob_phase += delta * 2.2
	trash_sprite.position = _base_sprite_pos + Vector2(0.0, sin(_bob_phase) * 2.5)
	trash_sprite.rotation = sin(_bob_phase * 0.7) * 0.14


func enforce_water_bounds() -> void:
	var game := get_parent().get_parent()
	if game.has_water_surface():
		global_position.y = maxf(global_position.y, game.get_water_surface_y() + _surface_clearance)


func _on_area_entered(area: Area2D) -> void:
	if collected or GameState.game_over or not GameState.running:
		return

	if area.name != &"PickupArea":
		return

	# Sayacın bu nesneyi artık toplanmış kabul etmesini sağla.
	collected = true

	var cleaned := GameState.collect_trash(own_pollution, coin_reward)

	if AudioManager:
		if trash_sprite.texture and "toxic" in trash_sprite.texture.resource_path.to_lower():
			AudioManager.play_toxic()
		else:
			AudioManager.play_trash()

	print(
		"%s toplandı | +%d Coin | -%.1f Kirlilik | Güncel Kirlilik: %.1f" % [
			trash_name,
			coin_reward,
			cleaned,
			GameState.pollution
		]
	)

	queue_free()


func _apply_random_texture() -> void:
	if trash_textures.is_empty():
		return

	var chosen_texture: Texture2D = null
	var path_filter: String = ""

	# Seviyeye göre hikayesel çöp dağılımı:
	match GameState.current_round:
		2:
			# Kargo gemisi kazası: Lastik, kimyasal şişeler ve variller
			if randf() < 0.65:
				path_filter = ["tire", "barrel", "red_bottle", "slime"].pick_random()
		4:
			# Zehirli varil krizi: Ağır toksik atıklar
			if randf() < 0.70:
				path_filter = ["barrel", "toxic", "slime"].pick_random()
		_:
			if GameState.current_round >= 3 and randf() < 0.35:
				path_filter = "toxic"

	if not path_filter.is_empty():
		for tex in trash_textures:
			if path_filter in tex.resource_path.to_lower():
				chosen_texture = tex
				break

	if chosen_texture == null:
		chosen_texture = trash_textures.pick_random() as Texture2D

	if chosen_texture == null:
		return

	trash_sprite.texture = chosen_texture

	var path := chosen_texture.resource_path.to_lower()
	if "barrel" in path:
		trash_name = "Toksik Atık Varili"
		coin_reward = 3
		pollution_reduction = 7.0
	elif "slime" in path:
		trash_name = "Kimyasal Balçık"
		coin_reward = 3
		pollution_reduction = 6.0
	elif "tire" in path:
		trash_name = "Atık Lastik"
		coin_reward = 2
		pollution_reduction = 5.0
	elif "toxic" in path:
		trash_name = "Radyoaktif Atık"
		coin_reward = 3
		pollution_reduction = 7.0
	elif "black_bag" in path or "bag" in path:
		trash_name = "Çöp Torbası"
		coin_reward = 2
		pollution_reduction = 4.5
	elif "red_bottle" in path:
		trash_name = "Kimyasal Şişe"
		coin_reward = 2
		pollution_reduction = 4.0
	elif "glass" in path or "green_bottle" in path:
		trash_name = "Cam Şişe"
		coin_reward = 1
		pollution_reduction = 3.5
	else:
		trash_name = "Plastik Şişe"
		coin_reward = 1
		pollution_reduction = 3.5

	# Farklı çözünürlüklerdeki görselleri ortak boyuta getir (~40-45px)
	var image_size := chosen_texture.get_size()
	var longest_side := maxf(image_size.x, image_size.y)
	if longest_side > 400.0:
		trash_sprite.scale = Vector2.ONE * (1200.0 / longest_side)
	else:
		trash_sprite.scale = Vector2.ONE * (44.0 / maxf(longest_side, 1.0))
	# Eski görsellerde geniş şeffaf kenarlar var; görünen atığın üstünü koru.
	var used := chosen_texture.get_image().get_used_rect()
	var top := (used.position.y - image_size.y * 0.5) * trash_sprite.scale.y
	var left := (used.position.x - image_size.x * 0.5) * trash_sprite.scale.x
	var right := (used.end.x - image_size.x * 0.5) * trash_sprite.scale.x
	_surface_clearance = maxf(32.0, -top + maxf(absf(left), absf(right)) * sin(0.14) + 3.0)
