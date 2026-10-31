extends CanvasModulate

const CLEAN_COLOR := Color.WHITE
const DIRTY_COLOR := Color(0.6, 0.55, 0.35)

var target_color := CLEAN_COLOR

@onready var background: ColorRect = get_node("../Background")


func _ready() -> void:
	# Mağaza açıldığında da renk geçişi tamamlanabilsin.
	process_mode = Node.PROCESS_MODE_ALWAYS

	background.color = Color("#4db6d6")
	background.z_index = -10
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_resize_background()
	get_viewport().size_changed.connect(_resize_background)

	GameState.pollution_changed.connect(_on_pollution_changed)
	_on_pollution_changed(GameState.pollution)
	color = target_color


func _process(delta: float) -> void:
	var blend := 1.0 - exp(-6.0 * delta)
	color = color.lerp(target_color, blend)


func _on_pollution_changed(value: float) -> void:
	var pollution_ratio := clampf(value / 100.0, 0.0, 1.0)
	target_color = CLEAN_COLOR.lerp(DIRTY_COLOR, pollution_ratio)


func _resize_background() -> void:
	var screen := get_viewport_rect()
	background.position = screen.position
	background.size = screen.size
