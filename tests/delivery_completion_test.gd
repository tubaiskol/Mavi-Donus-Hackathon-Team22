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
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	var spawner := game.get_node("Spawner")
	spawner.set_process(false)
	spawner.get_node("Timer").stop()
	for trash in get_nodes_in_group("trash"):
		trash.remove_from_group("trash")
		trash.queue_free()
	await process_frame
	for level in [1, 5]:
		state.current_round = level
		state.game_over = false
		state.running = true
		state.remaining_trash = 0
		state.carried_trash = 3
		spawner.spawned_total = spawner.total_trash
		game.time_left = 0.1
		game._process(1.0)
		check(state.running and not state.game_over, "Level ended before cargo delivery")
		check(game.time_left == 0.1, "Timer expired on the return to the container")
		check("teslim" in game.time_label.text, "Container guidance is missing")
		check(not game.get_node("ShopPanel").visible, "Completion panel opened before delivery")
		game.time_left = 0.0
		game._check_level_completion()
		check(state.running, "Zero timer blocked delivery phase")
		var before: int = state.delivered_trash
		game._try_deliver_trash()
		check(state.carried_trash == 0 and state.delivered_trash == before + 3, "Delivery counters are wrong")
		check(not state.running, "Level did not complete after delivery")
		if level == 5:
			check(state.game_over and game._result_title.text == "Kazandın!", "Final delivery did not win the game")
		else:
			check(game.get_node("ShopPanel").visible, "Intermediate completion panel is missing")
		game._process(1.0)
		check(game._last_result_win if level == 5 else not state.game_over, "Completed level was overwritten by a loss")
		game.get_node("ShopPanel").hide()
	# Temizlik bitmediyse normal süre sınırı geçerliliğini korur.
	state.game_over = false
	state.running = true
	state.remaining_trash = 1
	spawner.spawned_total = spawner.total_trash - 1
	game.time_left = 0.1
	game._process(1.0)
	check(state.game_over and game._result_title.text == "Kaybettin", "Unfinished cleanup no longer respects the timer")
	check(not "Toplanan" in game._result_pol.text and not "Konteyner" in game._result_pol.text, "Loss panel exposes removed trash statistics")
	game.queue_free()
	await process_frame
	print("Delivery completion checks: %d failures." % failures)
	quit.call_deferred(0 if failures == 0 else 1)
