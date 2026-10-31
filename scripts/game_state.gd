extends Node

signal pollution_changed(value: float)
signal coins_changed(value: int)
signal boat_changed(boat_id: String)
signal carried_trash_changed(carried: int, delivered: int)
signal quests_changed
signal toast_requested(message: String, duration: float)
signal round_ended
signal game_won
signal game_lost

const INITIAL_TRASH_POLLUTION := 7.0
const NEW_TRASH_POLLUTION := 3.5

const BOAT_CATALOG := {
	"red": {
		"name": "Kırmızı Balıkçı Teknesi",
		"cost": 0,
		"radius_bonus": 0.0,
		"delivery_bonus": 0,
		"desc": "Standart kıyı temizlik teknesi"
	},
	"blue": {
		"name": "Mavi Temizlik Gemisi",
		"cost": 10,
		"radius_bonus": 15.0,
		"delivery_bonus": 1,
		"desc": "Toplama alanı +15 | Konteyner bonusu +1 coin"
	},
	"emerald": {
		"name": "Yeşil Eko-Katamaran",
		"cost": 18,
		"radius_bonus": 25.0,
		"delivery_bonus": 2,
		"desc": "Toplama alanı +25 | Konteyner bonusu +2 coin"
	},
	"gold": {
		"name": "Altın Sahil Güvenlik",
		"cost": 28,
		"radius_bonus": 35.0,
		"delivery_bonus": 3,
		"desc": "Toplama alanı +35 | Konteyner bonusu +3 coin"
	},
	"royal": {
		"name": "Mor Okyanus Gemisi",
		"cost": 40,
		"radius_bonus": 48.0,
		"delivery_bonus": 4,
		"desc": "Toplama alanı +48 | Konteyner bonusu +4 coin"
	}
}

const BOAT_ORDER := ["red", "blue", "emerald", "gold", "royal"]

# Oyuncunun gördüğü toplam kirlilik (0 - 100 arası, en az %50'den başlar).
var pollution := 50.0

# Toplam kirliliğin iki kaynağı: denizdeki atıklar ve dizel motor emisyonu.
var trash_pollution := 50.0
var motor_pollution := 0.0

# Seviyede kalan toplam çöp (henüz spawn olmamış olanlar dahil).
var remaining_trash := 15
# Başlangıçtaki 7-8 çöpün her birinin başlangıç kirliliğindeki payı.
var initial_trash_unit_pollution := 7.0

# Dizel motor emisyonu (Seviye 1'de 1.5/sn, sonraki seviyelerde zorlaşır).
var emission_per_sec := 1.50
var has_solar := false
var has_wide_net := false
var has_blue_boat := false
var owned_boats: Array[String] = ["red"]
var selected_boat := "red"

var trash_value := -4.0
var turtle_value := -10.0
var fish_penalty := 5.0

var coins := 0
var total_collected_trash := 0
var carried_trash := 0
var delivered_trash := 0
var rescued_turtles := 0

var boat_speed := 220.0
var pickup_radius := 40.0

var round_time := 60.0
var current_round := 1
var running := false
var game_over := false

var quests: Array[Dictionary] = []


func _ready() -> void:
	_init_quests()


func _init_quests() -> void:
	quests = [
		{
			"id": "deliver_5",
			"title": "İlk Teslimat: Konteynere 5 çöp dök",
			"target": 5,
			"progress": 0,
			"reward": 5,
			"completed": false
		},
		{
			"id": "deliver_15",
			"title": "Geri Dönüşümcü: Konteynere 15 çöp dök",
			"target": 15,
			"progress": 0,
			"reward": 12,
			"completed": false
		},
		{
			"id": "collect_20",
			"title": "Deniz Süpürgesi: Denizden 20 çöp topla",
			"target": 20,
			"progress": 0,
			"reward": 8,
			"completed": false
		},
		{
			"id": "rescue_2",
			"title": "Caretta Dostu: 2 Caretta kurtar",
			"target": 2,
			"progress": 0,
			"reward": 10,
			"completed": false
		},
		{
			"id": "buy_solar",
			"title": "Temiz Enerji: Güneş Paneli satın al",
			"target": 1,
			"progress": 0,
			"reward": 8,
			"completed": false
		},
		{
			"id": "deliver_30",
			"title": "Mavi Kahraman: Konteynere 30 çöp dök",
			"target": 30,
			"progress": 0,
			"reward": 25,
			"completed": false
		}
	]


func get_round_time() -> float:
	match current_round:
		1: return 60.0
		2: return 55.0
		3: return 52.0
		4: return 48.0
		_: return 45.0


func get_min_pollution_for_level(level: int) -> float:
	# Kirlilik en az %50'den başlar ve seviyeye göre başlangıçtaki 7-8 çöple tutarlıdır.
	match level:
		1: return 50.0
		2: return 52.0
		3: return 56.0
		4: return 58.0
		_: return 60.0


func update_emission_for_current_round() -> void:
	if has_solar:
		emission_per_sec = 0.0
	else:
		emission_per_sec = 1.50 + (current_round - 1) * 0.15


func recalculate_pickup_radius() -> void:
	var base := 40.0
	if has_wide_net:
		base += 25.0
	if BOAT_CATALOG.has(selected_boat):
		base += float(BOAT_CATALOG[selected_boat]["radius_bonus"])
	pickup_radius = base


func start_next_level() -> void:
	current_round += 1
	round_time = get_round_time()
	update_emission_for_current_round()


func start_level_pollution(total_trash: int = 15, initial_trash: int = 7) -> void:
	remaining_trash = maxi(total_trash, 1)
	var safe_initial := maxi(initial_trash, 1)
	var min_pol := get_min_pollution_for_level(current_round)
	var calculated_pol := float(safe_initial) * INITIAL_TRASH_POLLUTION
	trash_pollution = clampf(maxf(min_pol, calculated_pol), 50.0, 85.0)
	initial_trash_unit_pollution = trash_pollution / float(safe_initial)
	motor_pollution = 0.0
	_update_pollution()


func get_initial_trash_unit_pollution() -> float:
	return initial_trash_unit_pollution


func add_new_trash_pollution(amount: float = NEW_TRASH_POLLUTION) -> void:
	if game_over:
		return

	var added := maxf(amount, 0.0)
	trash_pollution += added
	_update_pollution()


func collect_trash(clean_amount: float = 4.0, coin_amount: int = 1) -> float:
	if game_over or not running:
		return 0.0

	var before_pol := pollution
	var own_clean := maxf(absf(clean_amount), 0.0)

	# Çöp kendi kirlilik payını ve kalan motor emisyonunun eşit payını temizler.
	var motor_share := 0.0
	if remaining_trash > 0:
		motor_share = motor_pollution / float(remaining_trash)

	trash_pollution = maxf(trash_pollution - own_clean, 0.0)
	motor_pollution = maxf(motor_pollution - motor_share, 0.0)

	remaining_trash = maxi(remaining_trash - 1, 0)
	if remaining_trash == 0:
		trash_pollution = 0.0
		motor_pollution = 0.0

	total_collected_trash += 1
	carried_trash += 1
	add_coins(coin_amount)
	_update_pollution()
	carried_trash_changed.emit(carried_trash, delivered_trash)
	_update_quests()

	return maxf(before_pol - pollution, own_clean)


func deliver_carried_trash() -> int:
	if carried_trash <= 0 or game_over:
		return 0

	var count := carried_trash
	carried_trash = 0
	delivered_trash += count

	var bonus_per_trash := 1
	if BOAT_CATALOG.has(selected_boat):
		bonus_per_trash += int(BOAT_CATALOG[selected_boat]["delivery_bonus"])

	var bonus_coins := count * bonus_per_trash
	add_coins(bonus_coins)
	carried_trash_changed.emit(carried_trash, delivered_trash)
	show_toast(
		"Çöp Konteynerine %d çöp döküldü! +%d Ek Coin kazandın!" % [count, bonus_coins],
		3.0
	)
	_update_quests()
	return bonus_coins


func record_turtle_rescue() -> void:
	rescued_turtles += 1
	_update_quests()


func _update_quests() -> void:
	var changed := false
	for q in quests:
		var qid: String = q["id"]
		var prev_prog: int = q["progress"]
		match qid:
			"deliver_5", "deliver_15", "deliver_30":
				q["progress"] = mini(delivered_trash, int(q["target"]))
			"collect_20":
				q["progress"] = mini(total_collected_trash, int(q["target"]))
			"rescue_2":
				q["progress"] = mini(rescued_turtles, int(q["target"]))
			"buy_solar":
				q["progress"] = 1 if has_solar else 0

		if q["progress"] != prev_prog:
			changed = true

		if not q["completed"] and int(q["progress"]) >= int(q["target"]):
			q["completed"] = true
			changed = true
			var reward: int = int(q["reward"])
			add_coins(reward)
			if AudioManager:
				AudioManager.play_win()
			show_toast(
				"Görev Tamamlandı: %s (+%d Coin!)" % [q["title"], reward],
				3.5
			)

	if changed:
		quests_changed.emit()


func get_active_quest_summary() -> String:
	for q in quests:
		if not q["completed"]:
			return "Görev: %s (%d/%d) [+%d Coin]" % [
				q["title"],
				int(q["progress"]),
				int(q["target"]),
				int(q["reward"])
			]
	return "Tüm Görevler Tamamlandı! Harika iş!"


func clean_motor_pollution(amount: float) -> void:
	if game_over:
		return

	var cleaning := maxf(amount, 0.0)
	var cleaned_motor := minf(motor_pollution, cleaning)
	motor_pollution -= cleaned_motor
	cleaning -= cleaned_motor

	if cleaning > 0.0:
		trash_pollution = maxf(trash_pollution - cleaning, 0.0)

	_update_pollution()


func add_pollution(amount: float) -> void:
	if game_over:
		return

	if amount >= 0.0:
		motor_pollution += amount
		_update_pollution()
	else:
		clean_motor_pollution(-amount)


func _update_pollution() -> void:
	pollution = clampf(trash_pollution + motor_pollution, 0.0, 100.0)
	pollution_changed.emit(pollution)

	if pollution >= 100.0 and not game_over:
		game_over = true
		running = false
		game_lost.emit()


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	coins_changed.emit(coins)


func is_boat_owned(boat_id: String) -> bool:
	return boat_id in owned_boats


func buy_or_select_boat(boat_id: String) -> bool:
	if not BOAT_CATALOG.has(boat_id):
		return false

	if is_boat_owned(boat_id):
		set_boat(boat_id)
		return true

	var cost: int = int(BOAT_CATALOG[boat_id]["cost"])
	if coins < cost:
		return false

	owned_boats.append(boat_id)
	if boat_id != "red":
		has_blue_boat = true
	add_coins(-cost)
	set_boat(boat_id)
	return true


func set_boat(boat_id: String) -> void:
	selected_boat = boat_id
	recalculate_pickup_radius()
	boat_changed.emit(selected_boat)


func get_boat_name(boat_id: String = "") -> String:
	var id := selected_boat if boat_id.is_empty() else boat_id
	if BOAT_CATALOG.has(id):
		return String(BOAT_CATALOG[id]["name"])
	return "Kırmızı Balıkçı Teknesi"


func show_toast(message: String, duration: float = 3.0) -> void:
	toast_requested.emit(message, duration)


func reset() -> void:
	current_round = 1
	has_solar = false
	has_wide_net = false
	has_blue_boat = false
	owned_boats = ["red"]
	selected_boat = "red"
	update_emission_for_current_round()
	round_time = get_round_time()
	coins = 0
	total_collected_trash = 0
	carried_trash = 0
	delivered_trash = 0
	rescued_turtles = 0
	boat_speed = 220.0
	recalculate_pickup_radius()
	running = false
	game_over = false

	_init_quests()
	start_level_pollution(15, 7)
	coins_changed.emit(coins)
	boat_changed.emit(selected_boat)
	carried_trash_changed.emit(carried_trash, delivered_trash)
	quests_changed.emit()
