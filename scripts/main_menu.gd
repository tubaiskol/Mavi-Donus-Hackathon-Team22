extends Control

@onready var start_button: TextureButton = $CenterContainer/MenuBox/ButtonsBox/StartButton


func _ready() -> void:
	get_tree().paused = false
	GameState.running = false
	start_button.pressed.connect(_start_game)
	_position_menu_buttons()


func _start_game() -> void:
	if AudioManager:
		AudioManager.play_button()
	start_button.disabled = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _position_menu_buttons() -> void:
	var box: Control = $CenterContainer/MenuBox/ButtonsBox
	box.custom_minimum_size = Vector2(420, 280)

	_set_bubble_rect(
		box.get_node("StartButton"),
		Vector2(120, 0),
		180
	)
	_set_bubble_rect(
		box.get_node("HelpButton"),
		Vector2(0, 140),
		140
	)
	_set_bubble_rect(
		box.get_node("SettingsButton"),
		Vector2(280, 140),
		140
	)


func _set_bubble_rect(
	button: TextureButton,
	local_position: Vector2,
	diameter: float
) -> void:
	# Assetin büyük piksel boyutu butonu büyütmesin.
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_normal = _make_oval_texture(
		Color(0.03, 0.24, 0.30, 0.50)
	)
	button.texture_hover = _make_oval_texture(
		Color(0.04, 0.34, 0.42, 0.68)
	)
	button.texture_pressed = _make_oval_texture(
		Color(0.02, 0.16, 0.22, 0.78)
	)
	button.custom_minimum_size = Vector2.ZERO

	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	button.scale = Vector2.ONE
	button.position = local_position
	button.size = Vector2(diameter, diameter)

	var caption: Label = button.get_node("BubbleText")
	caption.custom_minimum_size = Vector2.ZERO
	caption.scale = Vector2.ONE
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_oval_texture(fill_color: Color) -> GradientTexture2D:
	var border_color := Color(0.75, 0.96, 1.0, 0.85)
	var transparent_color := Color(0.75, 0.96, 1.0, 0.0)

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([
		0.0, 0.88, 0.94, 0.98, 1.0
	])
	gradient.colors = PackedColorArray([
		fill_color,
		fill_color,
		border_color,
		border_color,
		transparent_color
	])

	var oval := GradientTexture2D.new()
	oval.width = 300
	oval.height = 200
	oval.gradient = gradient
	oval.fill = GradientTexture2D.FILL_RADIAL
	oval.fill_from = Vector2(0.5, 0.5)
	oval.fill_to = Vector2(1.0, 0.5)

	return oval
