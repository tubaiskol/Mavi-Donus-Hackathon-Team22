extends SceneTree

var failures := 0
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160), Vector2i(3440, 1440), Vector2i(1280, 1024), Vector2i(844, 390), Vector2i(1280, 800), Vector2i(390, 844)]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 5:
		await process_frame

func check_screen() -> Rect2:
	var screen := root.get_visible_rect()
	var physical := Vector2(root.size)
	check(absf(screen.size.aspect() - physical.aspect()) < 0.01, "Unused screen area at %s" % root.size)
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "UI is being upscaled as a bitmap")
	return screen

func run() -> void:
	var state := root.get_node("GameState")
	state.current_round = 1
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for size in SIZES:
		root.size = size
		await settle()
		var screen := check_screen()
		check(menu.get_node("Background").get_global_rect().is_equal_approx(screen), "Menu background does not cover the screen")
		check(screen.encloses(menu.get_node("CenterContainer/MenuBox").get_global_rect()), "Main menu is clipped at %s" % size)
		menu._open_fleet()
		await settle()
		var card: Control = menu._fleet_overlay.get_node("CenterContainer/PanelContainer")
		check(screen.encloses(card.get_global_rect()), "Category menu does not fit the screen")
		menu._switch_menu_shop_tab(0)
		await settle()
		check(screen.encloses(card.get_global_rect()), "Catalog does not fit the screen")
		menu._fleet_overlay.hide()
	menu.queue_free()
	await process_frame
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	state.running = false
	var shop := game.get_node("ShopPanel")
	for size in SIZES:
		root.size = size
		await settle()
		var screen := check_screen()
		var background := game.get_node("Background") as Control
		check(background.get_global_rect().is_equal_approx(screen), "Game background does not cover the screen")
		check(background.get_node("SeaTexture").get_global_rect().is_equal_approx(screen), "Sea image leaves blank space")
		check(screen.encloses(game.get_reserved_panels_rect()), "Right panels are clipped")
		check(screen.encloses(game.get_node("HUD").get_stats_panel_rect()), "Statistics are clipped")
		state.running = true
		if not shop.visible:
			shop.toggle_manual_shop()
		await settle()
		check(screen.encloses(shop.panel.get_global_rect()), "Shop does not fit the screen")
		check(shop.panel.get_global_rect().get_center().distance_to(screen.get_center()) < 1, "Open shop is not recentered on resize")
		state.running = false
	game.queue_free()
	await settle()
	print("Responsive checks: %d failures (8 screen sizes, main menu, catalog, game background, HUD, open shop)." % failures)
	quit.call_deferred(0 if failures == 0 else 1)
