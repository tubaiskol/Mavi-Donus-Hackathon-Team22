extends Area2D

@export var is_initial_trash := true

@export var trash_textures: Array[Texture2D] = []

@onready var trash_sprite: Sprite2D = $Sprite2D

var own_pollution := 0.0
var collected := false


func _ready() -> void:
	_apply_random_texture()
	if is_initial_trash:
		# Başlangıçtaki 50 puana zaten dahil.
		own_pollution = GameState.INITIAL_TRASH_POLLUTION
	else:
		own_pollution = GameState.NEW_TRASH_POLLUTION
		GameState.add_new_trash_pollution()

	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if collected or GameState.game_over or not GameState.running:
		return

	if area.name != &"PickupArea":
		return

	# Sayacın bu nesneyi artık toplanmış kabul etmesini sağla.
	collected = true

	GameState.collect_trash(own_pollution)

	print(
		"Çöp toplandı | Atık payı: ", own_pollution,
		" | Kirlilik: ", GameState.pollution
	)

	queue_free()

func _apply_random_texture() -> void:
	if trash_textures.is_empty():
		return

	var chosen_texture := trash_textures.pick_random() as Texture2D
	if chosen_texture == null:
		return

	trash_sprite.texture = chosen_texture

	# Farklı çözünürlüklerdeki görselleri ortak boyuta getir.
	var image_size := chosen_texture.get_size()
	var longest_side := maxf(image_size.x, image_size.y)

	trash_sprite.scale = Vector2.ONE * (
		1200.0 / maxf(longest_side, 1.0)
	)
