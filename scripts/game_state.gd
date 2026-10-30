extends Node

signal pollution_changed(value: float)
signal coins_changed(value: int)
signal round_ended
signal game_won
signal game_lost

var pollution := 40.0
var emission_per_sec := 0.25
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


func _process(delta: float) -> void:
	if running and not game_over and not has_solar:
		add_pollution(emission_per_sec * delta)


func add_pollution(amount: float) -> void:
	if game_over:
		return

	pollution = clampf(pollution + amount, 0.0, 100.0)
	pollution_changed.emit(pollution)

	if pollution >= 100.0:
		game_over = true
		running = false
		game_lost.emit()


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


func reset() -> void:
	pollution = 40.0
	has_solar = false
	coins = 0
	boat_speed = 220.0
	pickup_radius = 40.0
	current_round = 1
	running = false
	game_over = false

	pollution_changed.emit(pollution)
	coins_changed.emit(coins)
