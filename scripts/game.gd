extends Node2D

const TOTAL_LEVELS := 5
const MENU_FONT := preload("res://assets/menu_font.ttf")

@export_range(1, 5, 1) var test_start_level: int = 1

var time_left := 0.0

@onready var spawner = $Spawner
@onready var top_info: VBoxContainer = $HUD/TopInfo
@onready var level_label: Label = $HUD/TopInfo/LevelLabel
@onready var time_label: Label = $HUD/TopInfo/TimeRow/TimeLabel
@onready var shop_panel: CanvasLayer = $ShopPanel
@onready var continue_button: Button = $ShopPanel/PanelContainer/VBoxContainer/ContinueButton

var _result_layer: CanvasLayer
var _result_title: Label
var _result_pol: Label
var _result_msg: Label
var _drop_zone: Area2D
var _dock_pulse := 0.0
var _dock_title_label: Label
var _dock_sub_label: Label

var _pause_modal: CanvasLayer
var _delivery_guidance_timer := 0.0
var _turtle_guidance_timer := 0.0


func _ready() -> void:
	_style_top_info()
	_build_trash_drop_zone()
	_build_result_screen()
	_build_pause_modal()

	get_tree().paused = false

	if OS.is_debug_build() and test_start_level > 1 and GameState.current_round == 1:
		GameState.current_round = test_start_level

	# Mevcut seçili seviyeyi başlat (Asla zorla 1'e sıfırlamaz!)
	GameState.start_level_round(GameState.current_round)

	GameState.pollution_changed.connect(_on_pollution_changed)
	GameState.carried_trash_changed.connect(_on_carried_trash_changed)
	GameState.game_lost.connect(_on_game_lost)
	GameState.game_won.connect(_on_game_won)

	continue_button.pressed.connect(_start_next_level)
	continue_button.disabled = true

	spawner.start_level()
	time_left = GameState.round_time
	_update_time_label()
	_update_dock_labels()
	GameState.running = true

	GameState.show_toast(
		"Seviye %d Başladı (Kirlilik: %%%d). Çöpleri topla ve Konteynere dök!" % [
			GameState.current_round,
			roundi(GameState.pollution)
		],
		4.0
	)


func _style_top_info() -> void:
	top_info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_info.offset_top = 10.0
	top_info.offset_bottom = 120.0
	top_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_info.add_theme_constant_override("separation", 4)

	level_label.add_theme_font_size_override("font_size", 28)
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_label.add_theme_color_override("font_outline_color", Color(0.06, 0.20, 0.34, 0.96))
	level_label.add_theme_constant_override("outline_size", 7)

	time_label.add_theme_font_size_override("font_size", 28)
	time_label.add_theme_color_override("font_color", Color.WHITE)
	time_label.add_theme_color_override("font_outline_color", Color(0.06, 0.20, 0.34, 0.96))
	time_label.add_theme_constant_override("outline_size", 7)


func _build_trash_drop_zone() -> void:
	_drop_zone = Area2D.new()
	_drop_zone.name = "TrashDropZone"
	var screen := get_viewport_rect().size
	_drop_zone.position = Vector2(screen.x - 135.0, 102.0)
	add_child(_drop_zone)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 78.0
	shape.shape = circle
	_drop_zone.add_child(shape)

	_dock_title_label = Label.new()
	_dock_title_label.text = "♻️ ÇÖP KONTEYNERİ"
	_dock_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_title_label.position = Vector2(-115, -80)
	_dock_title_label.custom_minimum_size = Vector2(230, 26)
	if MENU_FONT:
		_dock_title_label.add_theme_font_override("font", MENU_FONT)
	_dock_title_label.add_theme_font_size_override("font_size", 16)
	_dock_title_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.82))
	_dock_title_label.add_theme_color_override("font_outline_color", Color(0.04, 0.18, 0.28, 0.96))
	_dock_title_label.add_theme_constant_override("outline_size", 5)
	_drop_zone.add_child(_dock_title_label)

	_dock_sub_label = Label.new()
	_dock_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_sub_label.position = Vector2(-120, 48)
	_dock_sub_label.custom_minimum_size = Vector2(240, 36)
	if MENU_FONT:
		_dock_sub_label.add_theme_font_override("font", MENU_FONT)
	_dock_sub_label.add_theme_font_size_override("font_size", 13)
	_dock_sub_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65))
	_dock_sub_label.add_theme_color_override("font_outline_color", Color(0.04, 0.18, 0.28, 0.96))
	_dock_sub_label.add_theme_constant_override("outline_size", 5)
	_drop_zone.add_child(_dock_sub_label)

	_drop_zone.area_entered.connect(_on_drop_zone_area_entered)
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	if _drop_zone:
		var screen := get_viewport_rect().size
		_drop_zone.position = Vector2(screen.x - 135.0, 102.0)


func _on_drop_zone_area_entered(area: Area2D) -> void:
	if area.name != &"PickupArea":
		return
	_try_deliver_trash()


func _try_deliver_trash() -> void:
	if GameState.carried_trash <= 0 or not GameState.running or GameState.game_over:
		return
	var earned := GameState.deliver_carried_trash()
	if earned > 0 and AudioManager:
		AudioManager.play_buy()
	_update_dock_labels()
	_check_level_completion()


func _on_carried_trash_changed(_carried: int, _delivered: int) -> void:
	_update_dock_labels()


func _update_dock_labels() -> void:
	if _dock_sub_label == null:
		return
	if GameState.carried_trash > 0:
		_dock_sub_label.text = "Buraya Bırak: %d Çöp (+Ek Coin!)\nToplam Dökülen: %d" % [
			GameState.carried_trash,
			GameState.delivered_trash
		]
		_dock_sub_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.38))
	else:
		_dock_sub_label.text = "Çöp topla ve buraya dök!\nToplam Dökülen: %d" % GameState.delivered_trash
		_dock_sub_label.add_theme_color_override("font_color", Color(0.85, 0.96, 1.0))


func _draw() -> void:
	if _drop_zone == null:
		return
	var c := _drop_zone.position
	var has_cargo := GameState.carried_trash > 0
	var pulse := 4.0 * sin(_dock_pulse * 3.5)

	var ring_col := Color(0.35, 1.0, 0.62, 0.75) if has_cargo else Color(0.65, 0.92, 1.0, 0.38)
	draw_circle(c, 68.0, Color(0.04, 0.22, 0.32, 0.45))
	draw_arc(c, 72.0 + pulse, 0.0, TAU, 48, ring_col, 3.5)

	draw_rect(Rect2(c + Vector2(-52, -36), Vector2(104, 72)), Color(0.24, 0.34, 0.42, 0.92), true)
	draw_rect(Rect2(c + Vector2(-52, -36), Vector2(104, 72)), Color(0.55, 0.85, 0.95, 0.85), false, 2.5)

	var bin_colors := [
		Color(0.18, 0.72, 0.42),
		Color(0.20, 0.58, 0.88),
		Color(0.92, 0.72, 0.18)
	]
	for i in 3:
		var bx := -38.0 + i * 28.0
		var bin_rect := Rect2(c + Vector2(bx, -22), Vector2(22, 44))
		draw_rect(bin_rect, bin_colors[i], true)
		draw_rect(bin_rect, Color(1, 1, 1, 0.75), false, 1.5)
		draw_rect(Rect2(c + Vector2(bx - 2, -26), Vector2(26, 6)), bin_colors[i].darkened(0.22), true)


func _process(delta: float) -> void:
	_dock_pulse += delta
	queue_redraw()

	if _delivery_guidance_timer > 0.0:
		_delivery_guidance_timer -= delta
	if _turtle_guidance_timer > 0.0:
		_turtle_guidance_timer -= delta

	if not GameState.running or GameState.game_over:
		return

	if _drop_zone and GameState.carried_trash > 0:
		for area in _drop_zone.get_overlapping_areas():
			if area.name == &"PickupArea":
				_try_deliver_trash()
				break

	time_left = maxf(time_left - delta, 0.0)
	_update_time_label()

	if time_left <= 0.0:
		_lose_level()
	else:
		_check_level_completion()


func _on_pollution_changed(_value: float) -> void:
	_check_level_completion()


func _has_unrescued_turtle() -> bool:
	for node in get_tree().get_nodes_in_group("turtle"):
		if is_instance_valid(node) and not bool(node.get("rescued")):
			return true
	return false


func _check_level_completion() -> void:
	if not GameState.running or GameState.game_over:
		return

	if time_left <= 0.0:
		return

	# Denizde henüz toplanmamış veya spawn olmamış çöp varsa seviyeyi bitirme
	if spawner.get_remaining_trash_count() > 0:
		return

	# 1) Teknede çöp varsa seviyeyi hemen kapatma! Oyuncuyu konteynere yönlendir
	if GameState.carried_trash > 0:
		if _delivery_guidance_timer <= 0.0:
			_delivery_guidance_timer = 3.5
			GameState.show_toast("Deniz temizlendi! Teknendeki %d çöpü Konteynere dök!" % GameState.carried_trash, 3.0)
		return

	# 2) Kurtarılmayı bekleyen Caretta varsa ve süre varken seviyeyi hemen kapatma!
	if _has_unrescued_turtle() and time_left > 4.0:
		if _turtle_guidance_timer <= 0.0:
			_turtle_guidance_timer = 4.0
			GameState.show_toast("Ağa takılı Caretta var! Onu kurtarmayı unutma!", 3.0)
		return

	# Tüm şartlar sağlandı: Seviye başarıyla tamamlandı!
	GameState.running = false
	get_tree().paused = true
	GameState.record_level_result(GameState.current_round, true)

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

	if AudioManager:
		AudioManager.play_button()

	continue_button.disabled = true
	shop_panel.hide()

	GameState.start_next_level()
	spawner.start_level()

	time_left = GameState.round_time
	_update_time_label()

	GameState.running = true
	get_tree().paused = false

	if GameState.has_solar:
		GameState.show_toast("Güneş paneli aktif! Emisyon sıfır.", 3.0)
	else:
		GameState.show_toast("%s ile %d. seviyeye başladın!" % [GameState.get_boat_name(), GameState.current_round], 3.0)


func _update_time_label() -> void:
	level_label.text = "TUR %d / %d" % [GameState.current_round, TOTAL_LEVELS]
	time_label.text = "%d sn" % ceili(time_left)
	if time_left <= 10.0:
		time_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
	else:
		time_label.add_theme_color_override("font_color", Color.WHITE)


func _lose_level() -> void:
	GameState.running = false
	GameState.game_over = true
	GameState.record_level_result(GameState.current_round, false)
	GameState.game_lost.emit()


func _on_game_won() -> void:
	time_label.text = "Kazandın! Beş seviyeyi de temizledin."
	_show_result(true)
	get_tree().paused = true


func _on_game_lost() -> void:
	if GameState.pollution >= 100.0:
		time_label.text = "Kaybettin! Kirlilik 100'e ulaştı."
	else:
		time_label.text = "Kaybettin! Temizliği süresinde tamamlayamadın."
	_show_result(false)
	get_tree().paused = true


func _show_result(win: bool) -> void:
	shop_panel.hide()
	_result_title.text = "Kazandın!" if win else "Kaybettin"
	_result_title.add_theme_color_override(
		"font_color",
		Color(0.08, 0.54, 0.44) if win else Color(0.82, 0.22, 0.20)
	)
	_result_pol.text = "Son kirlilik: %%%d  |  Toplanan: %d  |  Konteyner: %d" % [
		roundi(GameState.pollution),
		GameState.total_collected_trash,
		GameState.delivered_trash
	]
	if win:
		_result_msg.text = "Deniz nefes alıyor. Beş seviyeyi de temizledin! Temizlik bir tur, dönüşüm bir karar."
	elif GameState.pollution >= 100.0:
		_result_msg.text = "Deniz kirliliğe yenik düştü. Bu turu tekrar deneyebilirsin!"
	else:
		_result_msg.text = "Süre doldu! Bu turu tekrar oynayıp denizleri kurtarabilirsin."
	_result_layer.show()


# --- PAUSE (DURAKLATMA) MENÜSÜ ---
func _build_pause_modal() -> void:
	_pause_modal = CanvasLayer.new()
	_pause_modal.name = "PauseModalLayer"
	_pause_modal.layer = 15
	_pause_modal.visible = false
	_pause_modal.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_modal)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.10, 0.18, 0.70)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_modal.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if MENU_FONT:
		var th := Theme.new()
		th.default_font = MENU_FONT
		th.default_font_size = 20
		cc.theme = th
	_pause_modal.add_child(cc)

	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.99, 1.0, 0.97)
	sb.border_color = Color(0.18, 0.56, 0.76, 0.90)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(0.0, 0.08, 0.16, 0.40)
	sb.shadow_size = 20
	pc.add_theme_stylebox_override("panel", sb)
	cc.add_child(pc)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(440, 0)
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)

	var title := Label.new()
	title.text = "⏸️ OYUN DURAKLATILDI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.08, 0.24, 0.36))
	vb.add_child(title)

	var resume_btn := _make_result_button("▶️ Devam Et", toggle_pause, true)
	vb.add_child(resume_btn)

	var restart_btn := _make_result_button("🔄 Seviyeyi Yeniden Başlat", _restart_current_level, false)
	vb.add_child(restart_btn)

	var shop_btn := _make_result_button("🛒 Tersane & Mağaza", func():
		toggle_pause()
		if shop_panel and shop_panel.has_method("toggle_manual_shop"):
			shop_panel.toggle_manual_shop()
	, false)
	vb.add_child(shop_btn)

	var menu_btn := _make_result_button("🏠 Ana Menüye Dön", _return_to_menu, false)
	vb.add_child(menu_btn)


func toggle_pause() -> void:
	if GameState.game_over:
		return
	if AudioManager:
		AudioManager.play_button()

	if _pause_modal.visible:
		_pause_modal.hide()
		get_tree().paused = false
	else:
		_pause_modal.show()
		get_tree().paused = true


func _restart_current_level() -> void:
	if AudioManager:
		AudioManager.play_button()
	get_tree().paused = false
	# Kaybedilen veya mevcut seviyeyi baştan başlatır (Seviye 1'e zorlamaz!)
	GameState.start_level_round(GameState.current_round)
	get_tree().reload_current_scene()


func _build_result_screen() -> void:
	_result_layer = CanvasLayer.new()
	_result_layer.name = "ResultLayer"
	_result_layer.layer = 3
	_result_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_result_layer.visible = false
	add_child(_result_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.10, 0.18, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if MENU_FONT:
		var th := Theme.new()
		th.default_font = MENU_FONT
		th.default_font_size = 22
		cc.theme = th
	_result_layer.add_child(cc)

	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.99, 1.0, 0.95)
	sb.border_color = Color(0.18, 0.56, 0.76, 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(32)
	sb.shadow_color = Color(0.0, 0.08, 0.16, 0.38)
	sb.shadow_size = 18
	pc.add_theme_stylebox_override("panel", sb)
	cc.add_child(pc)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(540, 0)
	vb.add_theme_constant_override("separation", 16)
	pc.add_child(vb)

	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_size_override("font_size", 46)
	vb.add_child(_result_title)

	_result_pol = Label.new()
	_result_pol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_pol.add_theme_font_size_override("font_size", 22)
	_result_pol.add_theme_color_override("font_color", Color(0.12, 0.28, 0.40))
	vb.add_child(_result_pol)

	_result_msg = Label.new()
	_result_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_msg.add_theme_font_size_override("font_size", 20)
	_result_msg.add_theme_color_override("font_color", Color(0.20, 0.36, 0.48))
	vb.add_child(_result_msg)

	var replay_btn := _make_result_button("Tekrar Oyna", _restart_current_level, true)
	vb.add_child(replay_btn)

	var menu_btn := _make_result_button("Ana Menü", _return_to_menu, false)
	vb.add_child(menu_btn)


func _make_result_button(text: String, cb: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)

	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()
	var pressed := StyleBoxFlat.new()
	for sb in [normal, hover, pressed]:
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(2)

	if primary:
		normal.bg_color = Color(0.10, 0.56, 0.48)
		normal.border_color = Color(0.06, 0.38, 0.32)
		hover.bg_color = Color(0.14, 0.66, 0.56)
		hover.border_color = Color(0.08, 0.46, 0.38)
		pressed.bg_color = Color(0.08, 0.44, 0.38)
		pressed.border_color = Color(0.05, 0.30, 0.26)
	else:
		normal.bg_color = Color(0.14, 0.34, 0.48)
		normal.border_color = Color(0.24, 0.56, 0.74)
		hover.bg_color = Color(0.18, 0.44, 0.62)
		hover.border_color = Color(0.34, 0.70, 0.90)
		pressed.bg_color = Color(0.10, 0.26, 0.38)
		pressed.border_color = Color(0.18, 0.46, 0.64)

	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	return b


func _return_to_menu() -> void:
	if AudioManager:
		AudioManager.play_button()
	get_tree().paused = false
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
