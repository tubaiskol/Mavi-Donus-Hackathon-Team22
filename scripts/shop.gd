extends CanvasLayer

const NET_COST := 8
const SOLAR_COST := 15
const RED_BOAT_TEX := preload("res://assets/red_boat.png")
const BLUE_BOAT_TEX := preload("res://assets/blue_boat.png")

var _is_manual_open := false
var _boat_buttons: Dictionary = {}
var _active_tab := 0 # 0: Tersane, 1: Ekipman

@onready var panel: PanelContainer = $PanelContainer
@onready var vbox: VBoxContainer = $PanelContainer/VBoxContainer
@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var coins_row: HBoxContainer = $PanelContainer/VBoxContainer/CoinsRow
@onready var coins_label: Label = $PanelContainer/VBoxContainer/CoinsRow/CoinsLabel
@onready var legacy_boat_button: Button = $PanelContainer/VBoxContainer/SpeedButton
@onready var net_button: Button = $PanelContainer/VBoxContainer/NetButton
@onready var solar_button: Button = $PanelContainer/VBoxContainer/SolarButton
@onready var continue_button: Button = $PanelContainer/VBoxContainer/ContinueButton

var _subtitle_label: Label
var _trash_summary_label: Label
var _tabs_row: HBoxContainer
var _tab_shipyard_btn: Button
var _tab_equip_btn: Button
var _shipyard_box: VBoxContainer
var _equipment_box: VBoxContainer
var _boats_grid: GridContainer
var _close_manual_button: Button


func _ready() -> void:
	hide()
	_build_modern_shop_ui()

	GameState.round_ended.connect(_open_shop)
	GameState.coins_changed.connect(_refresh)
	GameState.boat_changed.connect(func(_id): _refresh(GameState.coins))

	net_button.pressed.connect(_buy_net)
	solar_button.pressed.connect(_buy_solar)

	continue_button.disabled = true
	_refresh(GameState.coins)


func _build_modern_shop_ui() -> void:
	# Arka plan karartma katmanı
	var dim := ColorRect.new()
	dim.name = "DimOverlay"
	dim.color = Color(0.02, 0.10, 0.18, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	move_child(dim, 0)

	panel.custom_minimum_size = Vector2(740, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.99, 1.0, 0.96)
	sb.border_color = Color(0.18, 0.56, 0.76, 0.88)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(24)
	sb.shadow_color = Color(0.0, 0.08, 0.16, 0.38)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)

	vbox.add_theme_constant_override("separation", 10)

	title_label.text = "Tersane & Mağaza"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(0.08, 0.24, 0.36))
	vbox.move_child(title_label, 0)

	_subtitle_label = Label.new()
	_subtitle_label.text = "Gemilerini geliştir, ağını genişlet ve güneş enerjisiyle temiz denizlere açıl!"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 16)
	_subtitle_label.add_theme_color_override("font_color", Color(0.20, 0.36, 0.48))
	vbox.add_child(_subtitle_label)
	vbox.move_child(_subtitle_label, 1)

	coins_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coins_row.add_theme_constant_override("separation", 10)
	var coin_icon := coins_row.get_node_or_null("CoinIcon") as TextureRect
	if coin_icon:
		coin_icon.custom_minimum_size = Vector2(34, 34)
	coins_label.add_theme_font_size_override("font_size", 28)
	coins_label.add_theme_color_override("font_color", Color(0.78, 0.52, 0.06))
	vbox.move_child(coins_row, 2)

	_trash_summary_label = Label.new()
	_trash_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trash_summary_label.add_theme_font_size_override("font_size", 15)
	_trash_summary_label.add_theme_color_override("font_color", Color(0.16, 0.44, 0.56))
	vbox.add_child(_trash_summary_label)
	vbox.move_child(_trash_summary_label, 3)

	# --- SEKMELER (Tersane ve Mağaza ayrı container) ---
	_tabs_row = HBoxContainer.new()
	_tabs_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs_row.add_theme_constant_override("separation", 16)
	vbox.add_child(_tabs_row)
	vbox.move_child(_tabs_row, 4)

	_tab_shipyard_btn = Button.new()
	_tab_shipyard_btn.text = "⚓ Tersane (Gemiler)"
	_tab_shipyard_btn.custom_minimum_size = Vector2(230, 44)
	_tab_shipyard_btn.add_theme_font_size_override("font_size", 18)
	_tab_shipyard_btn.pressed.connect(_switch_tab.bind(0))
	_tabs_row.add_child(_tab_shipyard_btn)

	_tab_equip_btn = Button.new()
	_tab_equip_btn.text = "🛠️ Mağaza (Ekipman)"
	_tab_equip_btn.custom_minimum_size = Vector2(230, 44)
	_tab_equip_btn.add_theme_font_size_override("font_size", 18)
	_tab_equip_btn.pressed.connect(_switch_tab.bind(1))
	_tabs_row.add_child(_tab_equip_btn)

	# --- TERSANE CONTAINER ---
	_shipyard_box = VBoxContainer.new()
	_shipyard_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_shipyard_box)
	vbox.move_child(_shipyard_box, 5)

	_boats_grid = GridContainer.new()
	_boats_grid.columns = 2
	_boats_grid.add_theme_constant_override("h_separation", 10)
	_boats_grid.add_theme_constant_override("v_separation", 8)
	_shipyard_box.add_child(_boats_grid)

	legacy_boat_button.hide()

	var red_icon := _make_boat_icon(RED_BOAT_TEX, Rect2i(360, 215, 250, 140), Color.WHITE)
	var blue_icon := _make_boat_icon(BLUE_BOAT_TEX, Rect2i(190, 260, 230, 140), Color.WHITE)
	var emerald_icon := _make_boat_icon(BLUE_BOAT_TEX, Rect2i(190, 260, 230, 140), Color(0.55, 1.0, 0.72))
	var gold_icon := _make_boat_icon(RED_BOAT_TEX, Rect2i(360, 215, 250, 140), Color(1.0, 0.88, 0.38))
	var royal_icon := _make_boat_icon(BLUE_BOAT_TEX, Rect2i(190, 260, 230, 140), Color(0.86, 0.68, 1.0))

	var icons := {
		"red": red_icon,
		"blue": blue_icon,
		"emerald": emerald_icon,
		"gold": gold_icon,
		"royal": royal_icon
	}

	for boat_id in GameState.BOAT_ORDER:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = icons.get(boat_id)
		b.expand_icon = false
		_style_shop_button(b, false)
		b.custom_minimum_size = Vector2(330, 50)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_on_boat_button_pressed.bind(boat_id))
		_boats_grid.add_child(b)
		_boat_buttons[boat_id] = b

	# --- EKİPMAN CONTAINER (Ayrı ferah kutu) ---
	_equipment_box = VBoxContainer.new()
	_equipment_box.add_theme_constant_override("separation", 14)
	vbox.add_child(_equipment_box)
	vbox.move_child(_equipment_box, 6)

	net_button.reparent(_equipment_box)
	solar_button.reparent(_equipment_box)

	for b in [net_button, solar_button]:
		_style_shop_button(b, false)
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_font_size_override("font_size", 19)

	_style_shop_button(continue_button, true)

	_close_manual_button = Button.new()
	_close_manual_button.text = "Kapat ve Oyuna Dön"
	_style_shop_button(_close_manual_button, true)
	_close_manual_button.hide()
	_close_manual_button.pressed.connect(toggle_manual_shop)
	vbox.add_child(_close_manual_button)

	_switch_tab(0)


func _switch_tab(idx: int) -> void:
	_active_tab = idx
	_shipyard_box.visible = (_active_tab == 0)
	_equipment_box.visible = (_active_tab == 1)

	var active_sb := StyleBoxFlat.new()
	active_sb.bg_color = Color(0.12, 0.54, 0.72)
	active_sb.border_color = Color(0.55, 0.88, 1.0)
	active_sb.set_border_width_all(2)
	active_sb.set_corner_radius_all(10)

	var inactive_sb := StyleBoxFlat.new()
	inactive_sb.bg_color = Color(0.82, 0.88, 0.92)
	inactive_sb.border_color = Color(0.60, 0.70, 0.78)
	inactive_sb.set_border_width_all(2)
	inactive_sb.set_corner_radius_all(10)

	if _active_tab == 0:
		_tab_shipyard_btn.add_theme_stylebox_override("normal", active_sb)
		_tab_shipyard_btn.add_theme_color_override("font_color", Color.WHITE)
		_tab_equip_btn.add_theme_stylebox_override("normal", inactive_sb)
		_tab_equip_btn.add_theme_color_override("font_color", Color(0.2, 0.3, 0.4))
	else:
		_tab_shipyard_btn.add_theme_stylebox_override("normal", inactive_sb)
		_tab_shipyard_btn.add_theme_color_override("font_color", Color(0.2, 0.3, 0.4))
		_tab_equip_btn.add_theme_stylebox_override("normal", active_sb)
		_tab_equip_btn.add_theme_color_override("font_color", Color.WHITE)


func _make_boat_icon(tex: Texture2D, region: Rect2i, tint: Color) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	var cropped := img.get_region(region)
	cropped.resize(54, 34, Image.INTERPOLATE_LANCZOS)
	if tint != Color.WHITE:
		for y in cropped.get_height():
			for x in cropped.get_width():
				var c := cropped.get_pixel(x, y)
				if c.a > 0.01:
					cropped.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
	return ImageTexture.create_from_image(cropped)


func _style_shop_button(b: Button, is_primary: bool) -> void:
	b.custom_minimum_size = Vector2(0, 52 if is_primary else 48)
	b.add_theme_font_size_override("font_size", 22 if is_primary else 18)

	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()
	var pressed := StyleBoxFlat.new()
	var disabled := StyleBoxFlat.new()

	for sb in [normal, hover, pressed, disabled]:
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		sb.set_border_width_all(2)

	if is_primary:
		normal.bg_color = Color(0.10, 0.56, 0.48)
		normal.border_color = Color(0.06, 0.38, 0.32)
		hover.bg_color = Color(0.14, 0.66, 0.56)
		hover.border_color = Color(0.08, 0.46, 0.38)
		pressed.bg_color = Color(0.08, 0.44, 0.38)
		pressed.border_color = Color(0.05, 0.30, 0.26)
		disabled.bg_color = Color(0.55, 0.65, 0.68, 0.65)
		disabled.border_color = Color(0.45, 0.55, 0.58, 0.5)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(0.9, 0.9, 0.9, 0.7))
	else:
		normal.bg_color = Color(0.12, 0.34, 0.48)
		normal.border_color = Color(0.24, 0.58, 0.76)
		hover.bg_color = Color(0.16, 0.44, 0.62)
		hover.border_color = Color(0.36, 0.74, 0.92)
		pressed.bg_color = Color(0.09, 0.26, 0.38)
		pressed.border_color = Color(0.18, 0.48, 0.66)
		disabled.bg_color = Color(0.78, 0.84, 0.88, 0.85)
		disabled.border_color = Color(0.64, 0.72, 0.78, 0.8)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.80))
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(0.32, 0.40, 0.46))

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)


func toggle_manual_shop() -> void:
	if visible and _is_manual_open:
		_is_manual_open = false
		hide()
		if GameState.running and not GameState.game_over:
			get_tree().paused = false
		return

	if not GameState.running or GameState.game_over:
		return

	_is_manual_open = true
	get_tree().paused = true
	_refresh(GameState.coins)
	continue_button.hide()
	_close_manual_button.show()
	show()
	_center_panel()


func _open_shop() -> void:
	if GameState.game_over or GameState.current_round >= 5:
		return

	_is_manual_open = false
	_refresh(GameState.coins)

	_close_manual_button.hide()
	continue_button.show()
	continue_button.disabled = false
	continue_button.text = "Devam Et  —  %d. Seviyeye Başla" % (
		GameState.current_round + 1
	)

	show()
	_center_panel()


func _center_panel() -> void:
	await get_tree().process_frame
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var screen_center := get_viewport().get_visible_rect().get_center()
	panel.position = screen_center - panel.size * 0.5


func _on_boat_button_pressed(boat_id: String) -> void:
	var was_owned := GameState.is_boat_owned(boat_id)
	if GameState.buy_or_select_boat(boat_id):
		if AudioManager:
			if was_owned:
				AudioManager.play_button()
			else:
				AudioManager.play_buy()
		_refresh(GameState.coins)


func _buy_net() -> void:
	if GameState.has_wide_net or GameState.coins < NET_COST:
		return

	if GameState.buy_net():
		if AudioManager:
			AudioManager.play_buy()
		_refresh(GameState.coins)


func _buy_solar() -> void:
	if GameState.has_solar or GameState.coins < SOLAR_COST:
		return

	if GameState.buy_solar():
		if AudioManager:
			AudioManager.play_solar()
		_refresh(GameState.coins)


func _refresh(value: int) -> void:
	coins_label.text = "%d Coin" % value
	if _trash_summary_label:
		_trash_summary_label.text = "Toplanan Çöp: %d  |  Konteynere Dökülen: %d" % [
			GameState.total_collected_trash,
			GameState.delivered_trash
		]

	for boat_id: String in _boat_buttons:
		var btn: Button = _boat_buttons[boat_id]
		var info: Dictionary = GameState.BOAT_CATALOG[boat_id]
		var b_name: String = info["name"]
		var cost: int = int(info["cost"])
		var r_bonus: int = int(info["radius_bonus"])
		var d_bonus: int = int(info["delivery_bonus"])
		var owned: bool = GameState.is_boat_owned(boat_id)
		var is_active: bool = (GameState.selected_boat == boat_id)

		var stat_txt := ""
		if r_bonus > 0:
			stat_txt = " (+%d Ağ, +%d Konteyner Coin)" % [r_bonus, d_bonus]

		if is_active:
			btn.text = "%s%s\n[Aktif Gemi]" % [b_name, stat_txt]
			btn.disabled = true
		elif owned:
			btn.text = "%s%s\n[Sahipsin — Seç]" % [b_name, stat_txt]
			btn.disabled = false
		else:
			btn.text = "%s%s\nSatın Al — %d Coin" % [b_name, stat_txt, cost]
			btn.disabled = value < cost

	var wide_owned := GameState.has_wide_net
	net_button.disabled = wide_owned or value < NET_COST
	solar_button.disabled = GameState.has_solar or value < SOLAR_COST

	if wide_owned:
		net_button.text = "Geniş Ağ (Toplama Alanı +25)  —  Alındı"
	else:
		net_button.text = "Geniş Ağ (Toplama Alanı +25)  —  %d coin" % NET_COST

	if GameState.has_solar:
		solar_button.text = "Güneş Paneli (Emisyon Sıfırlanır)  —  Alındı"
	else:
		solar_button.text = "Güneş Paneli (Emisyon Sıfırlanır)  —  %d coin" % SOLAR_COST
