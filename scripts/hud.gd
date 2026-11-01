extends CanvasLayer

const MENU_FONT := preload("res://assets/menu_font.ttf")
const PANEL_LAYOUT := preload("res://scripts/panel_layout.gd")

@onready var stats_box: VBoxContainer = $StatsBox
@onready var pollution_label: Label = $StatsBox/PollutionLabel
@onready var pollution_bar: ProgressBar = $StatsBox/PollutionBar
@onready var coins_row: HBoxContainer = $StatsBox/CoinsRow
@onready var coins_label: Label = $StatsBox/CoinsRow/CoinsLabel
@onready var trash_label: Label = $StatsBox/TrashLabel
@onready var emission_label: Label = $StatsBox/EmissionLabel
@onready var spawner = get_node("../Spawner")
@onready var shop_panel = get_node("../ShopPanel")
@onready var game_root = get_parent()

var _fill_style: StyleBoxFlat
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _boat_badge_label: Label
var _container_label: Label

# Sağ taraftaki bağımsız görev paneli
var _quests_side_panel: PanelContainer
var _quests_side_label: Label
var _quests_modal: Control
var _quests_list_vbox: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_style_hud()
	_build_side_quests_card()
	_build_quests_modal()

	GameState.pollution_changed.connect(_on_pollution_changed)
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.boat_changed.connect(_on_boat_changed)
	GameState.carried_trash_changed.connect(_on_carried_trash_changed)
	GameState.quests_changed.connect(_on_quests_changed)
	GameState.toast_requested.connect(show_toast)

	_on_pollution_changed(GameState.pollution)
	_on_coins_changed(GameState.coins)
	_on_boat_changed(GameState.selected_boat)
	_on_carried_trash_changed(GameState.carried_trash, GameState.delivered_trash)
	_on_quests_changed()
	_layout_side_quests_card()
	get_viewport().size_changed.connect(_layout_side_quests_card)
	_quests_side_panel.minimum_size_changed.connect(_layout_side_quests_card)
	_update_trash_label()
	_update_emission_label()


func _process(_delta: float) -> void:
	_update_trash_label()
	_update_emission_label()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			_toggle_shop_from_hud()
		elif event.physical_keycode == KEY_G:
			_toggle_quests_modal()
		elif event.physical_keycode in [KEY_P, KEY_ESCAPE]:
			_toggle_pause_from_hud()


func _style_hud() -> void:
	# Sol üst kart: Sadece temel istatistikler ve Tersane/Duraklat butonları
	var stats_panel := PanelContainer.new()
	stats_panel.name = "StatsBackdrop"
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.03, 0.16, 0.26, 0.76)
	card_sb.border_color = Color(0.55, 0.88, 1.0, 0.45)
	card_sb.set_border_width_all(2)
	card_sb.set_corner_radius_all(14)
	stats_panel.add_theme_stylebox_override("panel", card_sb)
	stats_panel.position = Vector2(12, 10)
	stats_panel.size = Vector2(356, 146)
	add_child(stats_panel)
	move_child(stats_panel, 0)

	stats_box.position = Vector2(22, 16)
	stats_box.custom_minimum_size = Vector2(336, 0)
	stats_box.add_theme_constant_override("separation", 5)

	# Kirlilik çubuğu
	pollution_bar.custom_minimum_size = Vector2(332, 22)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.06, 0.14, 0.22, 0.85)
	bg_sb.border_color = Color(0.75, 0.92, 1.0, 0.55)
	bg_sb.set_border_width_all(2)
	bg_sb.set_corner_radius_all(8)
	pollution_bar.add_theme_stylebox_override("background", bg_sb)

	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color = Color(0.25, 0.82, 0.65)
	_fill_style.set_corner_radius_all(6)
	pollution_bar.add_theme_stylebox_override("fill", _fill_style)

	# Coin satırı ve aktif gemi
	coins_row.add_theme_constant_override("separation", 8)
	var coin_icon := coins_row.get_node_or_null("CoinIcon") as TextureRect
	if coin_icon:
		coin_icon.custom_minimum_size = Vector2(26, 26)
	coins_label.add_theme_font_size_override("font_size", 22)
	coins_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.42))
	coins_label.add_theme_color_override("font_outline_color", Color(0.18, 0.12, 0.02, 0.95))
	coins_label.add_theme_constant_override("outline_size", 5)

	_boat_badge_label = Label.new()
	_boat_badge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boat_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boat_badge_label.add_theme_font_size_override("font_size", 14)
	_boat_badge_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	_boat_badge_label.add_theme_color_override("font_outline_color", Color(0.06, 0.20, 0.34))
	_boat_badge_label.add_theme_constant_override("outline_size", 4)
	coins_row.add_child(_boat_badge_label)

	for lbl in [pollution_label, trash_label, emission_label]:
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.20, 0.34, 0.95))
		lbl.add_theme_constant_override("outline_size", 5)

	pollution_label.add_theme_font_size_override("font_size", 19)
	emission_label.add_theme_font_size_override("font_size", 16)
	trash_label.add_theme_font_size_override("font_size", 16)

	_container_label = Label.new()
	_container_label.add_theme_font_size_override("font_size", 15)
	_container_label.add_theme_color_override("font_color", Color(0.68, 1.0, 0.80))
	_container_label.add_theme_color_override("font_outline_color", Color(0.05, 0.20, 0.32, 0.95))
	_container_label.add_theme_constant_override("outline_size", 4)
	stats_box.add_child(_container_label)

	# Üst orta duraklat butonu (Ortaya konumlandırıldı)
	var top_info: VBoxContainer = get_node_or_null("TopInfo") as VBoxContainer
	if top_info:
		var pause_btn := _make_hud_action_button("⏸️ Duraklat (ESC)", _toggle_pause_from_hud, Color(0.18, 0.38, 0.52))
		pause_btn.name = "CenterPauseButton"
		pause_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pause_btn.custom_minimum_size = Vector2(170, 32)
		top_info.add_child(pause_btn)

	# Alt orta bildirim kapsülü
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "ToastPanel"
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var toast_sb := StyleBoxFlat.new()
	toast_sb.bg_color = Color(0.03, 0.20, 0.32, 0.88)
	toast_sb.border_color = Color(0.58, 0.90, 1.0, 0.85)
	toast_sb.set_border_width_all(2)
	toast_sb.set_corner_radius_all(18)
	toast_sb.content_margin_left = 24
	toast_sb.content_margin_right = 24
	toast_sb.content_margin_top = 10
	toast_sb.content_margin_bottom = 10
	toast_sb.shadow_color = Color(0.0, 0.08, 0.16, 0.42)
	toast_sb.shadow_size = 10
	_toast_panel.add_theme_stylebox_override("panel", toast_sb)
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toast_panel.offset_left = 180.0
	_toast_panel.offset_right = -(PANEL_LAYOUT.WIDTH + PANEL_LAYOUT.EDGE_MARGIN + 16.0)
	_toast_panel.offset_top = -78.0
	_toast_panel.offset_bottom = -20.0
	_toast_panel.modulate.a = 0.0
	add_child(_toast_panel)

	_toast_label = Label.new()
	_toast_label.name = "ToastLabel"
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.add_theme_font_size_override("font_size", 20)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.88))
	_toast_label.add_theme_color_override("font_outline_color", Color(0.04, 0.18, 0.28, 0.96))
	_toast_label.add_theme_constant_override("outline_size", 5)
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(_toast_label)





func _build_side_quests_card() -> void:
	# Sağ altta, konteynerin hemen üstündeki görevler kartı.
	_quests_side_panel = PanelContainer.new()
	_quests_side_panel.name = "QuestsSideCard"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.18, 0.28, 0.85)
	sb.border_color = Color(0.96, 0.78, 0.28, 0.75)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_quests_side_panel.add_theme_stylebox_override("panel", sb)

	_quests_side_panel.custom_minimum_size = Vector2(PANEL_LAYOUT.WIDTH, 110)
	add_child(_quests_side_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_quests_side_panel.add_child(vb)

	var title_btn := Button.new()
	title_btn.text = "📋 Görevler (G)"
	title_btn.flat = true
	title_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_btn.add_theme_font_size_override("font_size", 16)
	title_btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	title_btn.pressed.connect(_toggle_quests_modal)
	vb.add_child(title_btn)

	_quests_side_label = Label.new()
	_quests_side_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quests_side_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quests_side_label.add_theme_font_size_override("font_size", 13)
	_quests_side_label.add_theme_color_override("font_color", Color(0.90, 0.96, 1.0))
	_quests_side_label.add_theme_color_override("font_outline_color", Color(0.04, 0.16, 0.26))
	_quests_side_label.add_theme_constant_override("outline_size", 4)
	vb.add_child(_quests_side_label)


func get_side_quests_rect() -> Rect2:
	var height := maxf(110.0, _quests_side_panel.get_combined_minimum_size().y)
	return PANEL_LAYOUT.quests_rect(get_viewport().get_visible_rect(), height)


func _layout_side_quests_card() -> void:
	var rect := get_side_quests_rect()
	_quests_side_panel.size = rect.size
	_quests_side_panel.position = rect.position


func _make_hud_action_button(text: String, cb: Callable, base_color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.pressed.connect(cb)

	var normal := StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.border_color = base_color.lightened(0.35)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = base_color.lightened(0.15)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = base_color.darkened(0.15)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	return b


func _toggle_shop_from_hud() -> void:
	if GameState.game_over:
		return
	if AudioManager:
		AudioManager.play_button()
	if shop_panel and shop_panel.has_method("toggle_manual_shop"):
		shop_panel.toggle_manual_shop()


func _toggle_pause_from_hud() -> void:
	if game_root and game_root.has_method("toggle_pause"):
		game_root.toggle_pause()


func _build_quests_modal() -> void:
	_quests_modal = Control.new()
	_quests_modal.name = "QuestsModal"
	_quests_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quests_modal.visible = false
	if MENU_FONT:
		var th := Theme.new()
		th.default_font = MENU_FONT
		th.default_font_size = 18
		_quests_modal.theme = th
	add_child(_quests_modal)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.10, 0.18, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quests_modal.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quests_modal.add_child(cc)

	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.99, 1.0, 0.96)
	sb.border_color = Color(0.18, 0.56, 0.76, 0.88)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(26)
	pc.add_theme_stylebox_override("panel", sb)
	cc.add_child(pc)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(580, 0)
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)

	var title := Label.new()
	title.text = "Deniz Temizliği Görevleri"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.08, 0.24, 0.36))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "Topladığın çöpleri sağ alt köşedeki Çöp Konteynerine bırakarak ek coin ve görev ödülleri kazan!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.20, 0.38, 0.50))
	vb.add_child(sub)

	_quests_list_vbox = VBoxContainer.new()
	_quests_list_vbox.add_theme_constant_override("separation", 8)
	vb.add_child(_quests_list_vbox)

	var close_btn := _make_hud_action_button("Kapat ve Oyuna Dön", _toggle_quests_modal, Color(0.10, 0.54, 0.44))
	close_btn.custom_minimum_size = Vector2(0, 48)
	close_btn.add_theme_font_size_override("font_size", 20)
	vb.add_child(close_btn)


func _toggle_quests_modal() -> void:
	if GameState.game_over:
		return
	if AudioManager:
		AudioManager.play_button()
	if _quests_modal.visible:
		_quests_modal.hide()
		if GameState.running and (shop_panel == null or not shop_panel.visible):
			get_tree().paused = false
	else:
		_refresh_quests_modal()
		_quests_modal.show()
		get_tree().paused = true


func _refresh_quests_modal() -> void:
	if _quests_list_vbox == null:
		return
	for c in _quests_list_vbox.get_children():
		c.queue_free()

	for q in GameState.quests:
		var row_panel := PanelContainer.new()
		var rsb := StyleBoxFlat.new()
		var done: bool = bool(q["completed"])
		rsb.bg_color = Color(0.84, 0.96, 0.88) if done else Color(0.88, 0.94, 0.98)
		rsb.border_color = Color(0.20, 0.68, 0.42) if done else Color(0.45, 0.72, 0.88)
		rsb.set_border_width_all(2)
		rsb.set_corner_radius_all(10)
		rsb.set_content_margin_all(10)
		row_panel.add_theme_stylebox_override("panel", rsb)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		row_panel.add_child(hbox)

		var status_lbl := Label.new()
		status_lbl.text = "✅" if done else "⏳"
		status_lbl.add_theme_font_size_override("font_size", 20)
		hbox.add_child(status_lbl)

		var title_lbl := Label.new()
		title_lbl.text = "%s  (%d / %d)" % [q["title"], int(q["progress"]), int(q["target"])]
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.add_theme_font_size_override("font_size", 16)
		title_lbl.add_theme_color_override("font_color", Color(0.08, 0.26, 0.36))
		hbox.add_child(title_lbl)

		var rew_lbl := Label.new()
		rew_lbl.text = "Tamamlandı!" if done else "+%d Coin" % int(q["reward"])
		rew_lbl.add_theme_font_size_override("font_size", 16)
		rew_lbl.add_theme_color_override(
			"font_color",
			Color(0.12, 0.56, 0.32) if done else Color(0.76, 0.48, 0.04)
		)
		hbox.add_child(rew_lbl)

		_quests_list_vbox.add_child(row_panel)


func show_toast(text: String, secs: float = 3.0) -> void:
	if _toast_label == null or _toast_panel == null:
		return
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.text = text
	_toast_panel.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(secs)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.6)


func _on_pollution_changed(value: float) -> void:
	pollution_bar.value = value
	pollution_label.text = "Kirlilik: %%%d / 100" % roundi(value)

	if _fill_style:
		var ratio := clampf(value / 100.0, 0.0, 1.0)
		var clean_col := Color(0.22, 0.82, 0.62)
		var mid_col := Color(0.95, 0.72, 0.20)
		var dirty_col := Color(0.92, 0.26, 0.22)
		if ratio < 0.5:
			_fill_style.bg_color = clean_col.lerp(mid_col, ratio * 2.0)
		else:
			_fill_style.bg_color = mid_col.lerp(dirty_col, (ratio - 0.5) * 2.0)


func _on_coins_changed(_value: int) -> void:
	coins_label.text = "%d Coin" % GameState.coins


func _on_boat_changed(boat_id: String) -> void:
	if _boat_badge_label:
		_boat_badge_label.text = GameState.get_boat_name(boat_id)


func _on_carried_trash_changed(carried: int, delivered: int) -> void:
	if _container_label:
		_container_label.text = "Teknede: %d Çöp | Konteynere: %d" % [carried, delivered]


func _on_quests_changed() -> void:
	if _quests_side_label:
		_quests_side_label.text = GameState.get_active_quest_summary()
	if _quests_modal and _quests_modal.visible:
		_refresh_quests_modal()


func _update_trash_label() -> void:
	var total: int = spawner.TOTAL_TRASH
	var remaining: int = spawner.get_remaining_trash_count()
	var collected := clampi(total - remaining, 0, total)

	trash_label.text = "Toplanan Çöp: %d / %d  (Kalan: %d)" % [
		collected,
		total,
		remaining
	]


func _update_emission_label() -> void:
	if GameState.has_solar:
		emission_label.text = "Emisyon: 0/sn (Güneş)"
		emission_label.add_theme_color_override("font_color", Color(0.58, 1.0, 0.72))
	else:
		emission_label.text = "Emisyon: +%.2f/sn (Dizel)" % GameState.emission_per_sec
		emission_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.52))
