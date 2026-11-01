extends SceneTree

var _failures := 0
var _game: Node2D
var _turtle_scene: PackedScene
var _trash_scene: PackedScene


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
	# Use an isolated APPDATA directory when running these checks.
	var state := root.get_node("GameState")
	_turtle_scene = load("res://scenes/turtle.tscn")
	_trash_scene = load("res://scenes/trash.tscn")
	state.current_round = 1
	state.has_solar = false
	_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(_game)
	current_scene = _game
	paused = false
	state.running = false
	_game.get_node("StoryBriefingLayer").hide()
	_game.set_process(false)
	_game.time_left = 60
	var spawner := _game.get_node("Spawner")
	spawner.set_process(false)
	spawner.get_node("Timer").stop()
	_game.get_node("TurtleSpawner").set_process(false)
	_game.get_node("FishSpawner").set_process(false)
	var boat := _game.get_node("Boat") as CharacterBody2D
	boat.set_physics_process(false)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	await _settle()

	for level in range(1, 6):
		state.current_round = level
		_game._update_level_bounds()
		for viewport_size in [Vector2i(1280, 720), Vector2i(1280, 960), Vector2i(1600, 720)]:
			root.size = viewport_size
			await _settle()
			var screen := _game.get_viewport_rect()
			var surface: float = _game.get_water_surface_y()
			if viewport_size == Vector2i(1280, 720):
				if level == 1:
					_check(is_equal_approx(surface, 300.0), "Reef surface is not aligned with its artwork")
				elif level == 2:
					_check(is_equal_approx(surface, 410.0), "Wreck surface is not aligned with its artwork")
			for sample in 300:
				var trash_pos: Vector2 = spawner._get_random_spawn_position()
				var turtle_pos: Vector2 = _game.get_node("TurtleSpawner")._get_safe_turtle_spawn_position(screen)
				_check(trash_pos.is_finite() and trash_pos.y >= surface + 32.0, "Trash spawned in the air, level %d" % level)
				_check(turtle_pos.is_finite() and turtle_pos.y >= surface + 50.0, "Turtle spawned in the air, level %d" % level)
				_check(not _game.get_reserved_panels_rect().grow(64).has_point(trash_pos), "Trash spawned on a panel")
				_check(not _game.get_reserved_panels_rect().grow(80).has_point(turtle_pos), "Turtle spawned on a panel")
			for boat_id in state.BOAT_ORDER:
				boat._apply_boat_texture(boat_id)
				var hull := boat.get_node("CollisionShape2D").shape as RectangleShape2D
				if level <= 2:
					boat.position = Vector2(screen.get_center().x, surface - boat.get_surface_contact_offset() + 10)
					await _settle()
					boat.velocity = Vector2(0, -10000)
					boat.move_and_slide()
					boat.enforce_water_bounds()
					_check(boat.position.y + boat.get_surface_contact_offset() >= surface - 0.1, "Boat's bottom strip crossed the sea surface: " + boat_id)
					_check(boat.position.y < surface, "Boat's upper body could not rise above the surface: " + boat_id)
				else:
					boat.position = Vector2(screen.get_center().x, 90)
					boat.enforce_water_bounds()
					_check(is_equal_approx(boat.position.y, 90), "Unexpected surface restriction in level %d" % level)
				if viewport_size == Vector2i(1280, 720):
					var quests: Rect2 = _game.get_node("HUD").get_side_quests_rect()
					var quest_y := maxf(quests.get_center().y, surface + hull.size.y * 0.5 + 2)
					boat.position = Vector2(quests.position.x - hull.size.x * 0.5 - 10, quest_y)
					await _settle()
					boat.velocity = Vector2(10000, 0)
					boat.move_and_slide()
					_check(boat.position.x > quests.position.x, "Quest card blocks %s in level %d" % [boat_id, level])
			await _check_live_entities(level, surface)

	# The final pickup locks all pollution sources at zero, including fish hits.
	state.current_round = 5
	_game._update_level_bounds()
	state.game_over = false
	state.running = true
	state.start_level_pollution(2, 2)
	state.add_pollution(5.0)
	_check(state.pollution > 0.0 and state.get_current_emission_rate() > 0.0, "Emission stopped before all trash was collected")
	state.collect_trash(7.0, 0)
	_check(not state.is_sea_clean(), "An uncollected or unspawned piece of trash was ignored")
	state.collect_trash(7.0, 0)
	_check(state.is_sea_clean() and state.carried_trash > 0, "Final pickup did not clean the sea before delivery")
	Input.action_press("move_right")
	boat._physics_process(0.1)
	Input.action_release("move_right")
	state.add_pollution(100.0)
	state.add_pollution(-10.0)
	_game.get_node("HUD")._update_emission_label()
	_check(state.pollution == 0.0 and state.motor_pollution == 0.0 and state.trash_pollution == 0.0, "Pollution increased after the sea was cleaned")
	_check(state.get_current_emission_rate() == 0.0, "Clean sea still has exhaust emission")
	_check("Deniz temiz" in _game.get_node("HUD").emission_label.text, "HUD still reports diesel emission after cleanup")
	state.start_level_pollution(15, 7)
	_check(state.pollution > 0.0 and state.get_current_emission_rate() > 0.0, "Next level did not restore normal pollution rules")
	state.running = false

	print("Level environment checks: %d failures (5 levels, 3 aspect ratios, all boats, 9000 spawn samples, clean-sea emission)." % _failures)
	_game.queue_free()
	for player in root.get_node("AudioManager").get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
	await _settle()
	quit.call_deferred(0 if _failures == 0 else 1)


func _check_live_entities(level: int, surface: float) -> void:
	var fish_spawner := _game.get_node("FishSpawner")
	fish_spawner.clean_level_fish()
	await _settle()
	fish_spawner._try_spawn_fish()
	for fish in fish_spawner.get_children():
		fish.set_physics_process(false)
		if level <= 2:
			_check(fish.global_position.y - fish.get_surface_clearance() >= surface - 0.1, "Fish spawned above the water")
		for frame in 240:
			fish._physics_process(1.0 / 60.0)
			if level <= 2:
				_check(fish.global_position.y - fish.get_surface_clearance() >= surface - 0.1, "Swimming fish crossed the sea surface")
		if level <= 2:
			fish.is_hit = true
			fish._escape_y = -1.0
			fish.global_position.y = surface + fish.get_surface_clearance()
			fish._physics_process(0.1)
			_check(fish.global_position.y - fish.get_surface_clearance() >= surface - 0.1, "Escaping fish crossed the sea surface")
		fish.queue_free()

	var turtle: Area2D = _turtle_scene.instantiate()
	turtle.global_position = Vector2(600, surface - 20)
	_game.get_node("TurtleSpawner").add_child(turtle)
	if level <= 2:
		_check(turtle.global_position.y >= surface + 50.0, "Turtle visual overlaps the air")
	turtle.queue_free()
	var trash: Area2D = _trash_scene.instantiate()
	trash.global_position = Vector2(700, surface - 20)
	_game.get_node("Spawner").add_child(trash)
	if level <= 2:
		_check(trash.global_position.y >= surface + trash._surface_clearance - 0.01, "Trash visual overlaps the air")
	trash.queue_free()
	await _settle()
