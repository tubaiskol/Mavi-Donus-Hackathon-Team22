extends Node2D

const TOTAL_LEVELS := 5

var time_left := 0.0

@onready var spawner = $Spawner
@onready var time_label: Label = $HUD/StatsBox/TimeLabel
@onready var shop_panel: CanvasLayer = $ShopPanel
@onready var continue_button: Button = $ShopPanel/PanelContainer/VBoxContainer/ContinueButton


func _ready() -> void:
	get_tree().paused = false
	GameState.reset()

	GameState.pollution_changed.connect(_on_pollution_changed)
	GameState.game_lost.connect(_on_game_lost)
	GameState.game_won.connect(_on_game_won)

	continue_button.pressed.connect(_start_next_level)
	continue_button.disabled = true

	spawner.start_level()
	time_left = GameState.round_time
	_update_time_label()
	GameState.running = true


func _process(delta: float) -> void:
	if not GameState.running or GameState.game_over:
		return

	time_left = maxf(time_left - delta, 0.0)
	_update_time_label()

	if time_left <= 0.0:
		_lose_level()
	else:
		_check_level_completion()


func _on_pollution_changed(_value: float) -> void:
	# Son çöp toplandığı anda kontrol et.
	# Böylece sonraki emisyon artışını beklemeyiz.
	_check_level_completion()


func _check_level_completion() -> void:
	if not GameState.running or GameState.game_over:
		return

	if time_left <= 0.0:
		return

	if GameState.pollution > 0.0:
		return

	# Henüz üretilmeyen çöpler de bu sayıya dahildir.
	if spawner.get_remaining_trash_count() > 0:
		return

	GameState.running = false
	get_tree().paused = true

	if GameState.current_round < TOTAL_LEVELS:
		time_label.text = "%d. seviye tamamlandı!" % GameState.current_round
		GameState.round_ended.emit()
	else:
		GameState.game_over = true
		GameState.game_won.emit()


func _start_next_level() -> void:
	if GameState.game_over or GameState.running:
		return

	if GameState.current_round >= TOTAL_LEVELS:
		return

	continue_button.disabled = true
	shop_panel.hide()

	# Kirlilik, coin ve yükseltmeler korunur.
	GameState.current_round += 1
	spawner.start_level()

	time_left = GameState.round_time
	_update_time_label()

	GameState.running = true
	get_tree().paused = false


func _update_time_label() -> void:
	time_label.text = "Seviye: %d / %d | Süre: %d sn" % [
		GameState.current_round,
		TOTAL_LEVELS,
		ceili(time_left)
	]


func _lose_level() -> void:
	GameState.running = false
	GameState.game_over = true
	GameState.game_lost.emit()


func _on_game_won() -> void:
	time_label.text = "Kazandın! Beş seviyeyi de temizledin."
	print("Kazandın!")
	get_tree().paused = true


func _on_game_lost() -> void:
	if GameState.pollution >= 100.0:
		time_label.text = "Kaybettin! Kirlilik 100'e ulaştı."
	else:
		time_label.text = "Kaybettin! Temizliği süresinde tamamlayamadın."

	get_tree().paused = true
