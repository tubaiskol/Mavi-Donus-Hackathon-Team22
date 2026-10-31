extends Node

signal pollution_changed(value: float)
signal coins_changed(value: int)
signal round_ended
signal game_won
signal game_lost

const INITIAL_TRASH_POLLUTION := 5.0
const NEW_TRASH_POLLUTION := 3.0

# Oyuncunun gördüğü toplam kirlilik.
var pollution := 50.0

# Toplamın iki kaynağı.
var trash_pollution := 50.0
var motor_pollution := 0.0

# Henüz üretilmeyen çöpler de dahildir.
var remaining_trash := 15
var _pollution_round := 1

var emission_per_sec := 0.50
var has_solar := false

# Mevcut scriptler geçiş sırasında bunları kullanmaya devam eder.
var trash_value := -5.0
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
	if not running or game_over:
		return

	if _pollution_round != current_round:
		start_level_pollution(15, 15)

	if not has_solar:
		motor_pollution += emission_per_sec * delta
		_update_pollution()


func start_level_pollution(
	total_trash: int = 15,
	_initial_trash: int = 15
) -> void:
	_pollution_round = current_round
	remaining_trash = total_trash
	# Seviyeye göre başlangıç kirliliği (1. seviyede 50, 5. seviyede 70)
	var base_pollution := 50.0 + (current_round - 1) * 5.0
	trash_pollution = clampf(base_pollution, 40.0, 80.0)
	motor_pollution = 0.0
	_update_pollution()


func add_new_trash_pollution() -> void:
	if game_over:
		return

	trash_pollution += NEW_TRASH_POLLUTION
	_update_pollution()


func collect_trash(_own_pollution: float = -1.0) -> float:
	if game_over or not running or remaining_trash <= 0:
		return 0.0

	# Her çöp, kalan çöp ve motor kirliliğinden eşit pay temizler.
	var trash_share := trash_pollution / float(remaining_trash)
	var motor_share := motor_pollution / float(remaining_trash)

	trash_pollution = maxf(
		trash_pollution - trash_share,
		0.0
	)
	motor_pollution = maxf(
		motor_pollution - motor_share,
		0.0
	)

	remaining_trash -= 1
	add_coins(1)
	_update_pollution()

	return trash_share


func clean_motor_pollution(amount: float) -> void:
	if game_over:
		return

	motor_pollution = maxf(
		motor_pollution - maxf(amount, 0.0),
		0.0
	)
	_update_pollution()


func add_pollution(amount: float) -> void:
	# Eski çöp ve caretta kodları yeni fonksiyonlara
	# bağlanana kadar mevcut davranışı korur.
	if game_over:
		return

	if amount >= 0.0:
		motor_pollution += amount
	else:
		var cleaning := -amount
		var cleaned_motor := minf(motor_pollution, cleaning)

		motor_pollution -= cleaned_motor
		cleaning -= cleaned_motor

		trash_pollution = maxf(
			trash_pollution - cleaning,
			0.0
		)

	_update_pollution()


func _update_pollution() -> void:
	pollution = clampf(
		trash_pollution + motor_pollution,
		0.0,
		100.0
	)
	pollution_changed.emit(pollution)

	if pollution >= 100.0 and not game_over:
		game_over = true
		running = false
		game_lost.emit()


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


func reset() -> void:
	has_solar = false
	emission_per_sec = 0.50
	coins = 0
	boat_speed = 220.0
	pickup_radius = 40.0
	current_round = 1
	running = false
	game_over = false

	start_level_pollution(15, 15)
	coins_changed.emit(coins)
