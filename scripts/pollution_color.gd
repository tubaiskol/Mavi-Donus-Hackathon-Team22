extends CanvasModulate

const CLEAN_COLOR := Color.WHITE
const DIRTY_COLOR := Color(0.58, 0.53, 0.34)

const LEVEL_ENVIRONMENT := preload("res://scripts/level_environment.gd")

var target_color := CLEAN_COLOR
var _bg_tex_rect: TextureRect

@onready var background: ColorRect = get_node("../Background")


func _ready() -> void:
	# Mağaza açıldığında da renk geçişi tamamlanabilsin.
	process_mode = Node.PROCESS_MODE_ALWAYS

	background.color = Color("#246b85")
	background.z_index = -10
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if background.get_node_or_null("SeaTexture") == null:
		_bg_tex_rect = TextureRect.new()
		_bg_tex_rect.name = "SeaTexture"
		_bg_tex_rect.texture = _get_bg_texture_for_round(GameState.current_round)
		_bg_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bg_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_bg_tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bg_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_tex_rect.modulate = Color(1.0, 1.0, 1.0, 0.92)
		background.add_child(_bg_tex_rect)

	_resize_background()
	get_viewport().size_changed.connect(_resize_background)

	GameState.pollution_changed.connect(_on_pollution_changed)
	_on_pollution_changed(GameState.pollution)
	color = target_color


func update_round_background(round_num: int) -> void:
	if _bg_tex_rect:
		_bg_tex_rect.texture = _get_bg_texture_for_round(round_num)


func _get_bg_texture_for_round(round_num: int) -> Texture2D:
	return LEVEL_ENVIRONMENT.BACKGROUNDS.get(round_num, LEVEL_ENVIRONMENT.BACKGROUNDS[1])


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
	if _bg_tex_rect:
		_bg_tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
