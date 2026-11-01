extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var state := root.get_node("GameState")
	state.current_round = 1
	state.owned_boats.assign(["red", "sub_basic"])
	state.selected_boat = "red"
	state.coins = 500
	state.has_solar = false
	state.has_wide_net = false
	state.has_clean_drive = false
	state.has_dive_collector = false
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var shop := game.get_node("ShopPanel")
	var hud := game.get_node("HUD")
	for level in range(1, 6):
		state.start_level_round(level)
		shop._refresh(state.coins)
		hud._on_carried_trash_changed(7, 12)
		check(state.is_vehicle_available(state.selected_boat), "Incompatible active vehicle at level %d" % level)
		for id in shop._boat_buttons:
			check(shop._boat_buttons[id].visible == state.is_vehicle_available(id), "Wrong shop vehicle visibility: " + id)
		if level <= 2:
			check("Teknede: 7" in hud._container_label.text, "Surface cargo label is wrong")
			check("Geniş Ağ" in shop.net_button.text and "Güneş Paneli" in shop.solar_button.text, "Surface gear is wrong")
			check(not state.buy_or_select_boat("sub_green"), "Submarine can be bought on the surface")
		else:
			check("Denizaltında: 7" in hud._container_label.text, "Underwater cargo label is wrong")
			check("Dalgıç" in shop.net_button.text and "Elektrikli" in shop.solar_button.text, "Dive gear is wrong")
			check(not state.buy_or_select_boat("blue"), "Ship can be bought underwater")
	state.start_level_round(2)
	check(state.buy_net() and state.buy_solar(), "Surface equipment purchase failed")
	state.start_next_level()
	check(state.selected_boat == "sub_basic", "Dive transition needs a free starting submarine")
	check(not state.has_collection_upgrade() and not state.has_clean_propulsion(), "Ship upgrades leaked into dive equipment")
	check(state.buy_net() and state.buy_solar(), "Dive equipment purchase failed")
	check(state.has_dive_collector and state.has_clean_drive, "Dive upgrades were not stored separately")
	check(state.get_current_emission_rate() == 0, "Electric propulsion still emits pollution")
	check(state.buy_or_select_boat("sub_green"), "Submarine purchase failed")
	state.save_game()
	state.has_clean_drive = false
	state.has_dive_collector = false
	state.load_game()
	check(state.has_clean_drive and state.has_dive_collector and state.selected_boat == "sub_green", "Dive purchases did not survive save/load")
	state.start_level_round(1)
	check(state.is_vehicle_available(state.selected_boat) and state.has_collection_upgrade() and state.has_clean_propulsion(), "Returning to the surface lost ship equipment")
	for level in range(1, 5):
		state.start_level_round(level)
		state.round_ended.emit()
		await process_frame
		check(shop.visible and shop._showing_completion, "Completion panel did not open")
		check("Tamamlandı" in shop.title_label.text and "Tebrikler" in shop._subtitle_label.text, "Completion feedback is missing")
		var visible_buttons := 0
		for button in shop.panel.find_children("*", "Button", true, false):
			if button.is_visible_in_tree():
				visible_buttons += 1
		check(visible_buttons == 2 and shop.continue_button.visible and shop._menu_return_button.visible, "Completion must show only Next and Home")
		check(not shop._tabs_row.visible and not shop._shipyard_box.visible and not shop._equipment_box.visible, "Shop content appears after level completion")
		shop.continue_button.pressed.emit()
		check(state.current_round == level + 1 and not shop.visible, "Next did not advance to the following level")
		game._close_story_dialog()
		shop.toggle_manual_shop()
		check(shop.visible and not shop._showing_completion and shop._tabs_row.visible and shop._shipyard_box.visible, "Pause shop was not restored after completion")
		check(not shop.continue_button.visible, "Next button appears in pause shop")
		shop.toggle_manual_shop()
		state.running = false
	game.queue_free()
	await process_frame
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for level in range(1, 6):
		state.start_level_round(level)
		menu._open_fleet()
		check(menu._menu_shop_categories.visible and menu._menu_shop_categories.get_child_count() == 4, "Main menu must open with four categories")
		check(not menu._menu_shipyard_box.visible and not menu._menu_equipment_box.visible, "Category overview shows products")
		for category in range(4):
			menu._menu_shop_categories.get_child(category).pressed.emit()
			check(menu._menu_shop_back.visible and menu._menu_shop_title.text == menu.SHOP_CATEGORIES[category], "Category heading/back navigation is wrong")
			if category < 2:
				for id in menu._menu_boat_buttons:
					check(menu._menu_boat_buttons[id].visible == ((id in ["sub_basic", "sub_fat", "sub_green"]) == (category == 1)), "Main menu catalog depends on current level")
			else:
				check(("Dalgıç" in menu._menu_net_btn.text) == (category == 3), "Wrong category equipment")
			menu._menu_shop_back.pressed.emit()
			check(menu._menu_shop_categories.visible and menu._menu_shop_title.text == "⚓ Tersane & Mağaza", "Back did not restore category overview")
	state.start_level_round(1)
	state.coins = 500
	check(state.buy_or_select_boat("sub_fat", true) and state.is_boat_owned("sub_fat"), "Main menu cannot buy an underwater vehicle on the surface")
	check(state.is_vehicle_available(state.selected_boat), "Catalog purchase activated an incompatible vehicle")
	state.has_dive_collector = false
	check(state.buy_net(1) and state.has_dive_collector, "Main menu cannot buy dive gear on the surface")
	menu.queue_free()
	for player in root.get_node("AudioManager").get_children():
		if player is AudioStreamPlayer:
			player.stop()
	await process_frame
	print("Shop progression checks: %d failures (5 levels, both shops, equipment purchases, save/load)." % failures)
	quit.call_deferred(0 if failures == 0 else 1)
