extends Area2D

const RESCUE_DURATION := 2.0
const RESCUE_REWARD := 5

var boat_near := false
var rescue_time := 0.0
var rescued := false

@onready var rescue_bar: ProgressBar = $RescueBar


func _ready() -> void:
	hide()
	rescue_bar.min_value = 0.0
	rescue_bar.max_value = RESCUE_DURATION
	rescue_bar.value = 0.0
	rescue_bar.hide()

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	if rescued:
		return

	# İlk seviyede caretta görünmez ve kurtarma ilerlemez.
	if GameState.current_round < 2:
		hide()
		return

	show()

	if not GameState.running or GameState.game_over:
		return

	if not boat_near:
		return

	rescue_time = minf(rescue_time + delta, RESCUE_DURATION)
	rescue_bar.value = rescue_time

	if rescue_time >= RESCUE_DURATION:
		_rescue()


func _on_area_entered(area: Area2D) -> void:
	if rescued or area.name != &"PickupArea":
		return

	boat_near = true
	rescue_bar.show()


func _on_area_exited(area: Area2D) -> void:
	if rescued or area.name != &"PickupArea":
		return

	boat_near = false
	rescue_time = 0.0
	rescue_bar.value = 0.0
	rescue_bar.hide()


func _rescue() -> void:
	rescued = true
	rescue_bar.hide()

	GameState.add_coins(RESCUE_REWARD)
	GameState.add_pollution(GameState.turtle_value)

	print("Caretta kurtarıldı! +5 coin")
	queue_free()
