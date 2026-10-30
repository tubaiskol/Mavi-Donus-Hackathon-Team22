extends CanvasLayer

@onready var pollution_label: Label = $StatsBox/PollutionLabel
@onready var pollution_bar: ProgressBar = $StatsBox/PollutionBar
@onready var coins_label: Label = $StatsBox/CoinsLabel
@onready var trash_label: Label = $StatsBox/TrashLabel
@onready var spawner = get_node("../Spawner")


func _ready() -> void:
	# Seviye sonunda oyun duraklasa da sayaç güncellensin.
	process_mode = Node.PROCESS_MODE_ALWAYS

	GameState.pollution_changed.connect(_on_pollution_changed)
	GameState.coins_changed.connect(_on_coins_changed)

	_on_pollution_changed(GameState.pollution)
	_on_coins_changed(GameState.coins)
	_update_trash_label()


func _process(_delta: float) -> void:
	_update_trash_label()


func _on_pollution_changed(value: float) -> void:
	pollution_bar.value = value
	pollution_label.text = "Kirlilik: %d / 100" % roundi(value)


func _on_coins_changed(value: int) -> void:
	coins_label.text = "Coin: %d" % value


func _update_trash_label() -> void:
	var total: int = spawner.TOTAL_TRASH
	var remaining: int = spawner.get_remaining_trash_count()
	var collected := clampi(total - remaining, 0, total)

	trash_label.text = "Toplanan çöp: %d / %d" % [
		collected,
		total
	]
