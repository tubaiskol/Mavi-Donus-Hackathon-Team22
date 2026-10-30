extends CanvasLayer

const SPEED_COST := 10
const NET_COST := 8
const SOLAR_COST := 15

var speed_bought := false
var net_bought := false

@onready var coins_label: Label = $PanelContainer/VBoxContainer/CoinsLabel
@onready var speed_button: Button = $PanelContainer/VBoxContainer/SpeedButton
@onready var net_button: Button = $PanelContainer/VBoxContainer/NetButton
@onready var solar_button: Button = $PanelContainer/VBoxContainer/SolarButton
@onready var continue_button: Button = $PanelContainer/VBoxContainer/ContinueButton


func _ready() -> void:
	hide()

	GameState.round_ended.connect(_open_shop)
	GameState.coins_changed.connect(_refresh)

	speed_button.pressed.connect(_buy_speed)
	net_button.pressed.connect(_buy_net)
	solar_button.pressed.connect(_buy_solar)

	# İkinci tura geçiş sonraki adımda bağlanacak.
	continue_button.disabled = true

	_refresh(GameState.coins)


func _open_shop() -> void:
	if GameState.game_over or GameState.current_round >= 5:
		return

	_refresh(GameState.coins)

	continue_button.disabled = false
	continue_button.text = "%d. Seviyeye Başla" % (
		GameState.current_round + 1
	)

	show()

	await get_tree().process_frame

	var panel: PanelContainer = $PanelContainer
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)

	var screen_center := get_viewport().get_visible_rect().get_center()
	panel.position = screen_center - panel.size * 0.5


func _buy_speed() -> void:
	if speed_bought or GameState.coins < SPEED_COST:
		return

	speed_bought = true
	GameState.boat_speed += 60.0
	GameState.add_coins(-SPEED_COST)


func _buy_net() -> void:
	if net_bought or GameState.coins < NET_COST:
		return

	net_bought = true
	GameState.pickup_radius += 25.0
	GameState.add_coins(-NET_COST)


func _buy_solar() -> void:
	if GameState.has_solar or GameState.coins < SOLAR_COST:
		return

	GameState.has_solar = true
	GameState.add_coins(-SOLAR_COST)


func _refresh(value: int) -> void:
	coins_label.text = "Coin: %d" % value

	speed_button.disabled = speed_bought or value < SPEED_COST
	net_button.disabled = net_bought or value < NET_COST
	solar_button.disabled = GameState.has_solar or value < SOLAR_COST

	if speed_bought:
		speed_button.text = "Hızlı Motor — Alındı"

	if net_bought:
		net_button.text = "Geniş Ağ — Alındı"

	if GameState.has_solar:
		solar_button.text = "Güneş Paneli — Alındı"
