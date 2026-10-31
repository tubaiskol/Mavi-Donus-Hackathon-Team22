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


func _ready() -> void:
	_bob_phase = randf() * TAU
	_base_sprite_pos = trash_sprite.position
	_apply_random_texture()

	if is_initial_trash:
		# Başlangıçtaki 7-8 çöp, başlangıç (%50+) kirliliğine zaten dahildir.
		own_pollution = GameState.get_initial_trash_unit_pollution()
	else:
		# Oyun sırasında yeni spawn olan çöpler denizin kirliliğini artırır!
		own_pollution = pollution_reduction
		GameState.add_new_trash_pollution(own_pollution)

	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if not GameState.running or GameState.game_over:
		return
	_bob_phase += delta * 2.2
	trash_sprite.position = _base_sprite_pos + Vector2(0.0, sin(_bob_phase) * 2.5)
	trash_sprite.rotation = sin(_bob_phase * 0.7) * 0.14


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

	# Seviye 3 ve sonrasında denizde daha fazla toksik atık belirir.
	if GameState.current_round >= 3 and randf() < 0.35:
		for tex in trash_textures:
			if "toxic" in tex.resource_path.to_lower():
				chosen_texture = tex
				break

	if chosen_texture == null:
		chosen_texture = trash_textures.pick_random() as Texture2D

	if chosen_texture == null:
		return

	trash_sprite.texture = chosen_texture

	var path := chosen_texture.resource_path.to_lower()
	if "toxic" in path:
		trash_name = "Toksik Atık"
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
	elif "green_bottle" in path:
		trash_name = "Cam Şişe"
		coin_reward = 1
		pollution_reduction = 3.5
	else:
		trash_name = "Plastik Şişe"
		coin_reward = 1
		pollution_reduction = 3.5

	# Farklı çözünürlüklerdeki görselleri ortak boyuta getir.
	var image_size := chosen_texture.get_size()
	var longest_side := maxf(image_size.x, image_size.y)

	trash_sprite.scale = Vector2.ONE * (
		1200.0 / maxf(longest_side, 1.0)
	)
