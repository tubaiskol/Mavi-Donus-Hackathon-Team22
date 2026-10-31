extends Area2D

@export var is_initial_trash := true

var own_pollution := 0.0
var collected := false


func _ready() -> void:
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
