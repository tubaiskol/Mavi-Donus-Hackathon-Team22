extends CanvasLayer

@onready var pollution_label: Label = $StatsBox/PollutionLabel
@onready var pollution_bar: ProgressBar = $StatsBox/PollutionBar
@onready var coins_label: Label = $StatsBox/CoinsLabel


func _ready() -> void:
	GameState.pollution_changed.connect(_on_pollution_changed)
	GameState.coins_changed.connect(_on_coins_changed)

	# Ekran ilk açıldığında mevcut değerleri göster.
	_on_pollution_changed(GameState.pollution)
	_on_coins_changed(GameState.coins)


func _on_pollution_changed(value: float) -> void:
	pollution_bar.value = value
	pollution_label.text = "Kirlilik: %d / 100" % roundi(value)


func _on_coins_changed(value: int) -> void:
	coins_label.text = "Coin: %d" % value
