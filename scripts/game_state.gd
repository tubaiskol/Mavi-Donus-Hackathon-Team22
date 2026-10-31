extends Node

signal pollution_changed(value: float)
signal coins_changed(value: int)
signal round_ended
signal game_won
signal game_lost

const INITIAL_TRASH_POLLUTION := 5.0
const NEW_TRASH_POLLUTION := 3.0

# Oyuncunun gördüğü toplam kirlilik (0 - 100 arası).
var pollution := 0.0

# Dizel motor emisyonu (saniyede +1.6 kirlilik).
# 30-35 saniye hareket edildiğinde rahatlıkla %50 ve üzerine çıkar.
var emission_per_sec := 1.60
var has_solar := false

var trash_value := -4.0
var turtle_value := -10.0
var fish_penalty := 5.0

var coins := 0
var boat_speed := 220.0
var pickup_radius := 40.0

var round_time := 60.0
var current_round := 1
var running := false
var game_over := false


func collect_trash(clean_amount: float = 4.0, coin_amount: int = 1) -> float:
	if game_over or not running:
		return 0.0

	var cleaned := absf(clean_amount)
	add_pollution(-cleaned)
	add_coins(coin_amount)
	return cleaned


func add_pollution(amount: float) -> void:
	if game_over:
		return

	pollution = clampf(pollution + amount, 0.0, 100.0)
	pollution_changed.emit(pollution)

	if pollution >= 100.0 and not game_over:
		game_over = true
		running = false
		game_lost.emit()


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


func reset() -> void:
	pollution = 0.0
	has_solar = false
	emission_per_sec = 1.60
	coins = 0
	boat_speed = 220.0
	pickup_radius = 40.0
	current_round = 1
	running = false
	game_over = false

	pollution_changed.emit(pollution)
	coins_changed.emit(coins)


# Geriye dönük uyumluluk için korunan fonksiyonlar
func start_level_pollution(_total_trash: int = 15, _initial_trash: int = 15) -> void:
	pass


func add_new_trash_pollution() -> void:
	pass


func clean_motor_pollution(_amount: float) -> void:
	pass
