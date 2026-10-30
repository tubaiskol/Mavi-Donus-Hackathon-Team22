extends Area2D

var collected := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if collected or GameState.game_over:
		return

	if area.name != &"PickupArea":
		return

	# Aynı çöpün birden fazla kez sayılmasını önle.
	collected = true

	GameState.add_pollution(GameState.trash_value)
	GameState.add_coins(1)

	print(
		"Çöp toplandı | Kirlilik: ", GameState.pollution,
		" | Coin: ", GameState.coins
	)

	queue_free()
