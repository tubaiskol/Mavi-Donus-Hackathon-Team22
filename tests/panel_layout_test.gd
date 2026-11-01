extends SceneTree

const LAYOUT := preload("res://scripts/panel_layout.gd")
var _failures := 0
var _game: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _settle() -> void:
	for frame in 4:
		await process_frame
		await physics_frame


func _run() -> void:
	# Run with an isolated APPDATA directory to preserve the player's save.
	root.get_node("GameState").current_round = 1
	_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(_game)
	current_scene = _game
	paused = false
	_game.set_process(false)
	_game.get_node("StoryBriefingLayer").hide()
	var state := root.get_node("GameState")
	state.running = false
	_game.get_node("Spawner/Timer").stop()
	_game.get_node("TurtleSpawner").set_process(false)
	_game.get_node("FishSpawner").set_process(false)
	var boat := _game.get_node("Boat") as CharacterBody2D
	boat.set_physics_process(false)
	await _settle()

	# Resize without viewport stretching to exercise real layout changes.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for viewport_size in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1600, 900)]:
		root.size = viewport_size
		await _settle()
		var screen := _game.get_viewport_rect()
		var dock := LAYOUT.dock_rect(screen)
		var container := LAYOUT.container_body_rect(screen)
		var quests := _game.get_node("HUD/QuestsSideCard") as Control
		var reserved: Rect2 = _game.get_reserved_panels_rect()
		_check(quests.get_global_rect().end.y <= dock.position.y - LAYOUT.GAP + 0.1, "Quests must be above the dock")
		_check(is_equal_approx(quests.position.x, dock.position.x), "Panels must align on the right")
		_check(_game.get_node("TrashDropZone").position.is_equal_approx(dock.get_center()), "Dock must follow viewport resizing")
		_check(screen.encloses(reserved), "Both panels must fit on screen")
		var spawner := _game.get_node("Spawner")
		var turtles := _game.get_node("TurtleSpawner")
		for sample in 1000:
			var trash_pos: Vector2 = spawner._get_random_spawn_position()
			var turtle_pos: Vector2 = turtles._get_safe_turtle_spawn_position(screen)
			_check(trash_pos.is_finite() and not reserved.grow(64).has_point(trash_pos), "Trash spawned over a panel")
			_check(turtle_pos.is_finite() and not reserved.grow(80).has_point(turtle_pos), "Turtle spawned over a panel")
		# Each hull must stop beside the panels and still reach the dock.
		for boat_id in ["red", "blue", "gulet", "emerald", "coast_guard", "sub_fat", "sub_green", "gold", "royal"]:
			boat._apply_boat_texture(boat_id)
			var hull := boat.get_node("CollisionShape2D").shape as RectangleShape2D
			boat.position = Vector2(container.position.x - hull.size.x * 0.5 - 20, dock.get_center().y)
			await _settle()
			# Large movement also verifies that the barrier cannot be tunneled through.
			boat.velocity = Vector2(10000, 0)
			boat.move_and_slide()
			await _settle()
			_check(boat.position.x + hull.size.x * 0.5 <= container.position.x + 0.1, "Boat crossed the container body: " + boat_id)
			_check(_game.get_node("TrashDropZone").overlaps_area(boat.get_node("PickupArea")), "Boat cannot deliver from beside the dock: " + boat_id)
			if boat_id == "red":
				var delivered_before: int = state.delivered_trash
				state.carried_trash = 3
				state.running = true
				_game._try_deliver_trash()
				_check(state.carried_trash == 0 and state.delivered_trash == delivered_before + 3, "Dockside delivery failed")
				state.running = false
			# The quest card is passable; the container still blocks entry.
			var quest_y := maxf(quests.get_global_rect().get_center().y, _game.get_water_surface_y() + hull.size.y * 0.5 + 2)
			boat.position = Vector2(reserved.position.x - hull.size.x * 0.5 - 10, quest_y)
			await _settle()
			boat.velocity = Vector2(10000, 0)
			boat.move_and_slide()
			_check(boat.position.x > reserved.position.x, "Boat cannot pass through the quest card: " + boat_id)
			boat.position = Vector2(container.get_center().x, container.position.y - hull.size.y * 0.5 - 20)
			await _settle()
			boat.velocity = Vector2(0, 10000)
			boat.move_and_slide()
			await _settle()
			_check(boat.position.y + hull.size.y * 0.5 <= container.position.y + 0.1, "Boat crossed the top of the container: " + boat_id)

	# Growing quest content must not turn the card into a physical obstacle.
	var hud := _game.get_node("HUD")
	hud._quests_side_label.text = "Görev satırı\n".repeat(12)
	await _settle()
	var barrier := _game.get_node("TrashContainerBarrier") as StaticBody2D
	var barrier_shape := barrier.get_child(0).shape as RectangleShape2D
	_check(is_equal_approx(barrier.position.y - barrier_shape.size.y * 0.5, LAYOUT.container_body_rect(_game.get_viewport_rect()).position.y), "Quest card growth blocked the water")

	# No legal water remains at this size; refuse to spawn instead of using UI.
	root.size = Vector2i(400, 240)
	await _settle()
	_check(not _game.get_node("Spawner")._get_random_spawn_position().is_finite(), "Trash fallback must reject an obstructed viewport")
	_check(not _game.get_node("TurtleSpawner")._get_safe_turtle_spawn_position(_game.get_viewport_rect()).is_finite(), "Turtle fallback must reject an obstructed viewport")

	print("Panel layout checks: %d failures (3 viewport sizes, 9 boats, 6000 spawn samples)." % _failures)
	_game.queue_free()
	for player in root.get_node("AudioManager").get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
	await _settle()
	quit.call_deferred(0 if _failures == 0 else 1)
