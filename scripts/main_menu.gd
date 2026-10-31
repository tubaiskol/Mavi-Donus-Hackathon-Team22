extends Control

const MENU_FONT := preload("res://assets/menu_font.ttf")

@onready var start_button: TextureButton = $CenterContainer/MenuBox/ButtonsBox/StartButton
@onready var help_button: TextureButton = $CenterContainer/MenuBox/ButtonsBox/HelpButton
@onready var settings_button: TextureButton = $CenterContainer/MenuBox/ButtonsBox/SettingsButton

var _howto_overlay: Control
var _settings_overlay: Control
var _fleet_overlay: Control
var _quests_overlay: Control

var _music_slider: HSlider
var _sfx_slider: HSlider
var _music_toggle_box: Button
var _sfx_toggle_box: Button


func _ready() -> void:
	get_tree().paused = false
	GameState.running = false
	start_button.pressed.connect(_start_game)
	help_button.pressed.connect(_open_howto)
	settings_button.pressed.connect(_open_settings)
	_style_subtitle_banner()
	_position_menu_buttons()
	_build_modals()


func _style_subtitle_banner() -> void:
	# Ana menüdeki alt açıklama yazısına (InfoLabel) şık deniz temalı UI kartı ekle
	var menu_box: VBoxContainer = $CenterContainer/MenuBox
	var info_label: Label = menu_box.get_node_or_null("InfoLabel") as Label
	if info_label == null:
		return

	var banner := PanelContainer.new()
	banner.name = "SubtitleBanner"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.22, 0.34, 0.76)
	sb.border_color = Color(0.62, 0.92, 1.0, 0.82)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0.0, 0.08, 0.16, 0.38)
	sb.shadow_size = 10
	banner.add_theme_stylebox_override("panel", sb)

	var idx := info_label.get_index()
	menu_box.add_child(banner)
	menu_box.move_child(banner, idx)
	info_label.reparent(banner)
	info_label.add_theme_font_size_override("font_size", 19)
	info_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.88))
	info_label.add_theme_color_override("font_outline_color", Color(0.04, 0.18, 0.28, 0.96))
	info_label.add_theme_constant_override("outline_size", 5)


func _start_game() -> void:
	if AudioManager:
		AudioManager.play_button()
	start_button.disabled = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _open_howto() -> void:
	if AudioManager:
		AudioManager.play_button()
	if _howto_overlay:
		_howto_overlay.show()


func _open_settings() -> void:
	if AudioManager:
		AudioManager.play_button()
	if _settings_overlay:
		_refresh_settings_ui()
		_settings_overlay.show()


func _open_fleet() -> void:
	if AudioManager:
		AudioManager.play_button()
	if _fleet_overlay:
		_fleet_overlay.show()


func _open_quests() -> void:
	if AudioManager:
		AudioManager.play_button()
	if _quests_overlay:
		_quests_overlay.show()


func _build_modals() -> void:
	var ui_theme := Theme.new()
	if MENU_FONT:
		ui_theme.default_font = MENU_FONT
		ui_theme.default_font_size = 20

	# --- NASIL OYNANIR MODALI (mavi_donus tarzı) ---
	var howto_vb := _create_modal_card("HowToModal", ui_theme)
	_howto_overlay = get_node("HowToModal")

	howto_vb.add_child(_modal_label("Nasıl Oynanır?", 36, Color(0.06, 0.24, 0.36)))
	howto_vb.add_child(_modal_label("• WASD veya Ok tuşlarıyla temizlik gemisini hareket ettir.", 19))
	howto_vb.add_child(_modal_label("• Deniz en az %50 kirlilik ve 7-8 varsayılan çöple başlar; suya yeni düşen çöpler kirliliği artırır!", 19))
	howto_vb.add_child(_modal_label("• Topladığın çöpleri sağ üst köşedeki ♻️ Çöp Konteynerine bırakarak ek coin ve görev ödülleri kazan.", 19))
	howto_vb.add_child(_modal_label("• 2. seviyeden itibaren ağa takılı Caretta'nın yanında 2 saniye kalarak onu kurtar (+5 Coin, -10 Kirlilik).", 19))
	howto_vb.add_child(_modal_label("• Oyun içinde sol üstteki 🛒 Mağaza (M) ve 📋 Görevler (G) butonlarıyla istediğin an tersaneye ve görevlere ulaşabilirsin.", 19))
	howto_vb.add_child(_modal_button("Geri Dön", func():
		if AudioManager:
			AudioManager.play_button()
		_howto_overlay.hide()
	))

	# --- MAĞAZA & GEMİLER TANITIM MODALI ---
	var fleet_vb := _create_modal_card("FleetModal", ui_theme)
	_fleet_overlay = get_node("FleetModal")
	fleet_vb.add_child(_modal_label("⚓ Mağaza & Gemi Çeşitleri", 34, Color(0.06, 0.24, 0.36)))
	fleet_vb.add_child(_modal_label("Oyun sırasında sol üstteki '🛒 Mağaza (M)' butonuyla veya tur sonlarında satın alabilirsin:", 18, Color(0.18, 0.36, 0.48)))
	for boat_id in GameState.BOAT_ORDER:
		var info: Dictionary = GameState.BOAT_CATALOG[boat_id]
		var cost_txt := "Başlangıç Gemisi" if int(info["cost"]) == 0 else "%d Coin" % int(info["cost"])
		fleet_vb.add_child(_modal_label("🚤 %s (%s) — %s" % [info["name"], cost_txt, info["desc"]], 18))
	fleet_vb.add_child(_modal_label("🛠️ Geniş Ağ (8 Coin): Toplama alanı +25  |  ☀️ Güneş Paneli (15 Coin): Emisyonu sıfırlar!", 18, Color(0.10, 0.46, 0.36)))
	fleet_vb.add_child(_modal_button("Kapat", func():
		if AudioManager:
			AudioManager.play_button()
		_fleet_overlay.hide()
	))

	# --- GÖREVLER MODALI ---
	var quests_vb := _create_modal_card("QuestsPreviewModal", ui_theme)
	_quests_overlay = get_node("QuestsPreviewModal")
	quests_vb.add_child(_modal_label("📋 Deniz Temizliği Görevleri", 34, Color(0.06, 0.24, 0.36)))
	quests_vb.add_child(_modal_label("Oyun içinde bu görevleri tamamlayarak ekstra coin ödülleri kazanırsın:", 18, Color(0.18, 0.36, 0.48)))
	for q in GameState.quests:
		quests_vb.add_child(_modal_label("🎯 %s  —  Ödül: +%d Coin" % [q["title"], int(q["reward"])], 18))
	quests_vb.add_child(_modal_button("Kapat", func():
		if AudioManager:
			AudioManager.play_button()
		_quests_overlay.hide()
	))

	# --- AYARLAR MODALI (Referans görseldeki OPTIONS tarzı) ---
	_build_sweet_settings_modal(ui_theme)


func _build_sweet_settings_modal(ui_theme: Theme) -> void:
	_settings_overlay = Control.new()
	_settings_overlay.name = "SettingsModal"
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.visible = false
	_settings_overlay.theme = ui_theme
	add_child(_settings_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.10, 0.20, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(cc)

	# Mavi-turkuaz parlak çerçeveli ana kart (OPTIONS görseli tarzı)
	var card := PanelContainer.new()
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.24, 0.76, 0.94, 0.97)
	card_sb.border_color = Color(0.92, 0.99, 1.0, 0.98)
	card_sb.set_border_width_all(5)
	card_sb.set_corner_radius_all(28)
	card_sb.content_margin_left = 34
	card_sb.content_margin_right = 34
	card_sb.content_margin_top = 26
	card_sb.content_margin_bottom = 28
	card_sb.shadow_color = Color(0.02, 0.14, 0.28, 0.52)
	card_sb.shadow_size = 20
	card.add_theme_stylebox_override("panel", card_sb)
	cc.add_child(card)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(460, 0)
	vb.add_theme_constant_override("separation", 22)
	card.add_child(vb)

	# Üst Başlık Satırı: Büyük sarı-turuncu konturlu "AYARLAR" + sağ üst "✖" butonu
	var header_hb := HBoxContainer.new()
	header_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(header_hb)

	var spacer_left := Control.new()
	spacer_left.custom_minimum_size = Vector2(42, 42)
	header_hb.add_child(spacer_left)

	var title_lbl := Label.new()
	title_lbl.text = "AYARLAR"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 46)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.20))
	title_lbl.add_theme_color_override("font_outline_color", Color(0.56, 0.24, 0.05, 1.0))
	title_lbl.add_theme_constant_override("outline_size", 10)
	header_hb.add_child(title_lbl)

	var close_x_btn := Button.new()
	close_x_btn.text = "✖"
	close_x_btn.custom_minimum_size = Vector2(42, 42)
	close_x_btn.add_theme_font_size_override("font_size", 20)
	close_x_btn.add_theme_color_override("font_color", Color(0.65, 0.12, 0.08))
	var x_sb := StyleBoxFlat.new()
	x_sb.bg_color = Color(1.0, 0.76, 0.18)
	x_sb.border_color = Color(0.92, 0.28, 0.16)
	x_sb.set_border_width_all(3)
	x_sb.set_corner_radius_all(21)
	close_x_btn.add_theme_stylebox_override("normal", x_sb)
	close_x_btn.add_theme_stylebox_override("hover", x_sb)
	close_x_btn.add_theme_stylebox_override("pressed", x_sb)
	close_x_btn.pressed.connect(func():
		if AudioManager:
			AudioManager.play_button()
		_settings_overlay.hide()
	)
	header_hb.add_child(close_x_btn)

	# 1. Satır: 🎵 Müzik (Büyük yazı + kalın kısa bar + sağda kare ful açık/kapalı kutusu)
	var music_row := _create_audio_control_row(
		"🎵 Müzik",
		func(val: float):
			if AudioManager:
				AudioManager.set_music_volume(val)
			_refresh_settings_ui(),
		func():
			if AudioManager:
				var next_val := 0.0 if AudioManager.music_volume > 1.0 else 100.0
				AudioManager.set_music_volume(next_val)
				AudioManager.play_button()
			_refresh_settings_ui()
	)
	_music_slider = music_row["slider"]
	_music_toggle_box = music_row["box"]
	vb.add_child(music_row["container"])

	# 2. Satır: 🔊 Ses (Büyük yazı + kalın kısa bar + sağda kare ful açık/kapalı kutusu)
	var sfx_row := _create_audio_control_row(
		"🔊 Ses",
		func(val: float):
			if AudioManager:
				AudioManager.set_sfx_volume(val)
			_refresh_settings_ui(),
		func():
			if AudioManager:
				var next_val := 0.0 if AudioManager.sfx_volume > 1.0 else 100.0
				AudioManager.set_sfx_volume(next_val)
				if next_val > 0.0:
					AudioManager.play_button()
			_refresh_settings_ui()
	)
	_sfx_slider = sfx_row["slider"]
	_sfx_toggle_box = sfx_row["box"]
	vb.add_child(sfx_row["container"])

	# Alt Buton: Görseldeki parlak turuncu-sarı "Quit / Tamam" butonu tarzında
	var bottom_center := HBoxContainer.new()
	bottom_center.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(bottom_center)

	var ok_btn := Button.new()
	ok_btn.text = "TAMAM"
	ok_btn.custom_minimum_size = Vector2(210, 56)
	ok_btn.add_theme_font_size_override("font_size", 28)
	ok_btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.85))
	ok_btn.add_theme_color_override("font_outline_color", Color(0.55, 0.22, 0.04))
	ok_btn.add_theme_constant_override("outline_size", 6)

	var ok_normal := StyleBoxFlat.new()
	ok_normal.bg_color = Color(0.98, 0.62, 0.14)
	ok_normal.border_color = Color(1.0, 0.94, 0.68)
	ok_normal.set_border_width_all(3)
	ok_normal.set_corner_radius_all(28)
	ok_normal.shadow_color = Color(0.45, 0.18, 0.02, 0.45)
	ok_normal.shadow_size = 8

	var ok_hover := ok_normal.duplicate() as StyleBoxFlat
	ok_hover.bg_color = Color(1.0, 0.70, 0.22)

	var ok_pressed := ok_normal.duplicate() as StyleBoxFlat
	ok_pressed.bg_color = Color(0.86, 0.50, 0.10)

	ok_btn.add_theme_stylebox_override("normal", ok_normal)
	ok_btn.add_theme_stylebox_override("hover", ok_hover)
	ok_btn.add_theme_stylebox_override("pressed", ok_pressed)
	ok_btn.pressed.connect(func():
		if AudioManager:
			AudioManager.play_button()
		_settings_overlay.hide()
	)
	bottom_center.add_child(ok_btn)

	_refresh_settings_ui()


func _create_audio_control_row(label_text: String, on_slide: Callable, on_box_toggle: Callable) -> Dictionary:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 14)

	# Sol: Daha büyük ve kalın ses etiketi
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(145, 44)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.04, 0.26, 0.48))
	lbl.add_theme_color_override("font_outline_color", Color(0.88, 0.98, 1.0, 0.90))
	lbl.add_theme_constant_override("outline_size", 5)
	hb.add_child(lbl)

	# Orta: Daha kalın ve daha kısa slider barı (turuncu-kırmızı dolgu + beyaz || tutamaç)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(210, 42)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var track_sb := StyleBoxFlat.new()
	track_sb.bg_color = Color(0.08, 0.44, 0.70)
	track_sb.border_color = Color(0.76, 0.95, 1.0, 0.92)
	track_sb.set_border_width_all(2)
	track_sb.set_corner_radius_all(14)
	track_sb.content_margin_top = 13
	track_sb.content_margin_bottom = 13

	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.96, 0.44, 0.18)
	fill_sb.border_color = Color(1.0, 0.84, 0.32)
	fill_sb.set_border_width_all(2)
	fill_sb.set_corner_radius_all(14)
	fill_sb.content_margin_top = 13
	fill_sb.content_margin_bottom = 13

	var fill_hl_sb := fill_sb.duplicate() as StyleBoxFlat
	fill_hl_sb.bg_color = Color(1.0, 0.54, 0.22)

	var grabber_tex := _make_pill_grabber_texture(false)
	var grabber_hl_tex := _make_pill_grabber_texture(true)

	slider.add_theme_stylebox_override("slider", track_sb)
	slider.add_theme_stylebox_override("grabber_area", fill_sb)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hl_sb)
	slider.add_theme_icon_override("grabber", grabber_tex)
	slider.add_theme_icon_override("grabber_highlight", grabber_hl_tex)
	slider.value_changed.connect(on_slide)
	hb.add_child(slider)

	# En sağ: Kare kutu kısayolu (Ful Açık / Ful Kapalı)
	var box_btn := Button.new()
	box_btn.custom_minimum_size = Vector2(46, 46)
	box_btn.tooltip_text = "Kısayol: Tam Açık (100%) / Tam Kapalı (0%)"
	box_btn.add_theme_font_size_override("font_size", 22)
	box_btn.pressed.connect(on_box_toggle)
	hb.add_child(box_btn)

	return {
		"container": hb,
		"slider": slider,
		"box": box_btn
	}


func _style_shortcut_box(box_btn: Button, is_open: bool) -> void:
	box_btn.text = "✓" if is_open else "✕"
	box_btn.add_theme_color_override("font_color", Color.WHITE)
	box_btn.add_theme_color_override("font_outline_color", Color(0.06, 0.20, 0.32))
	box_btn.add_theme_constant_override("outline_size", 4)

	var sb := StyleBoxFlat.new()
	if is_open:
		sb.bg_color = Color(0.18, 0.76, 0.38)
		sb.border_color = Color(0.88, 1.0, 0.90)
	else:
		sb.bg_color = Color(0.86, 0.28, 0.24)
		sb.border_color = Color(1.0, 0.86, 0.84)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)

	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = sb.bg_color.lightened(0.12)

	box_btn.add_theme_stylebox_override("normal", sb)
	box_btn.add_theme_stylebox_override("hover", hover)
	box_btn.add_theme_stylebox_override("pressed", sb)


func _make_pill_grabber_texture(highlight: bool) -> ImageTexture:
	# Görseldeki beyaz kapsül üzerinde mavi "||" çizgili tutamaç
	var w := 28
	var h := 36
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var body_col := Color(1.0, 1.0, 1.0, 1.0) if not highlight else Color(1.0, 0.98, 0.88, 1.0)
	var border_col := Color(0.55, 0.82, 0.96, 1.0)
	var bar_col := Color(0.10, 0.42, 0.68, 1.0)

	for y in h:
		for x in w:
			var dx := absf(float(x) - float(w - 1) * 0.5)
			var dy := maxf(absf(float(y) - float(h - 1) * 0.5) - 5.0, 0.0)
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= 12.5:
				if dist >= 10.2:
					img.set_pixel(x, y, border_col)
				else:
					img.set_pixel(x, y, body_col)

	for y in range(11, h - 11):
		for x in [10, 11, 16, 17]:
			img.set_pixel(x, y, bar_col)

	return ImageTexture.create_from_image(img)


func _create_modal_card(modal_name: String, ui_theme: Theme) -> VBoxContainer:
	var overlay := Control.new()
	overlay.name = modal_name
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.theme = ui_theme
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.10, 0.18, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)

	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.99, 1.0, 0.95)
	sb.border_color = Color(0.18, 0.56, 0.76, 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(0.0, 0.08, 0.16, 0.38)
	sb.shadow_size = 18
	pc.add_theme_stylebox_override("panel", sb)
	cc.add_child(pc)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(580, 0)
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	return vb


func _modal_label(text: String, fsize := 20, color := Color(0.12, 0.28, 0.40)) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	return l


func _modal_button(text: String, cb: Callable, primary := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override("font_size", 21)
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


func _refresh_settings_ui() -> void:
	var m_vol := AudioManager.music_volume if AudioManager else 80.0
	var s_vol := AudioManager.sfx_volume if AudioManager else 85.0

	if _music_slider:
		_music_slider.set_value_no_signal(m_vol)
	if _sfx_slider:
		_sfx_slider.set_value_no_signal(s_vol)

	if _music_toggle_box:
		_style_shortcut_box(_music_toggle_box, m_vol > 1.0)
	if _sfx_toggle_box:
		_style_shortcut_box(_sfx_toggle_box, s_vol > 1.0)


func _position_menu_buttons() -> void:
	var box: Control = $CenterContainer/MenuBox/ButtonsBox
	box.custom_minimum_size = Vector2(460, 340)

	_set_bubble_rect(
		box.get_node("StartButton"),
		Vector2(140, 0),
		175
	)
	_set_bubble_rect(
		box.get_node("HelpButton"),
		Vector2(5, 115),
		125
	)
	_set_bubble_rect(
		box.get_node("SettingsButton"),
		Vector2(325, 115),
		125
	)

	# Ana ekranda Mağaza & Gemiler ve Görevler baloncuk butonları
	var shop_btn := _create_extra_bubble_button("Mağaza &\nGemiler", Vector2(55, 225), 130, _open_fleet)
	box.add_child(shop_btn)

	var quests_btn := _create_extra_bubble_button("Görevler", Vector2(275, 225), 130, _open_quests)
	box.add_child(quests_btn)


func _create_extra_bubble_button(label_text: String, pos: Vector2, diameter: float, cb: Callable) -> TextureButton:
	var b := TextureButton.new()
	var lbl := Label.new()
	lbl.name = "BubbleText"
	lbl.text = label_text
	if MENU_FONT:
		lbl.add_theme_font_override("font", MENU_FONT)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1, 0.972549, 0.85882354, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0.08235294, 0.3019608, 0.40784314, 1))
	lbl.add_theme_constant_override("outline_size", 2)
	b.add_child(lbl)
	_set_bubble_rect(b, pos, diameter)
	b.pressed.connect(cb)
	return b


func _set_bubble_rect(
	button: TextureButton,
	local_position: Vector2,
	diameter: float
) -> void:
	# Assetin büyük piksel boyutu butonu büyütmesin.
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_normal = _make_oval_texture(
		Color(0.03, 0.24, 0.30, 0.56)
	)
	button.texture_hover = _make_oval_texture(
		Color(0.04, 0.36, 0.45, 0.74)
	)
	button.texture_pressed = _make_oval_texture(
		Color(0.02, 0.16, 0.22, 0.82)
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
