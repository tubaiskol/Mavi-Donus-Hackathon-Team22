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

const SAVE_PATH := "user://mavi_donus_save.json"

const INITIAL_TRASH_POLLUTION := 7.0
const NEW_TRASH_POLLUTION := 3.5

const BOAT_CATALOG := {
	"sub_basic": {
		"name": "Keşif Denizaltısı", "cost": 0, "radius_bonus": 0.0,
		"delivery_bonus": 0, "desc": "Standart derin su temizlik denizaltısı",
		"icon_path": "res://assets/vehicles/sub_green.png"
	},
	"red": {
		"name": "Kırmızı Balıkçı Teknesi",
		"cost": 0,
		"radius_bonus": 0.0,
		"delivery_bonus": 0,
		"desc": "Standart kıyı temizlik teknesi",
		"icon_path": "res://assets/vehicles/ship_red.png"
	},
	"blue": {
		"name": "Mavi Temizlik Botu",
		"cost": 10,
		"radius_bonus": 15.0,
		"delivery_bonus": 1,
		"desc": "Toplama alanı +15 | Konteyner bonusu +1 coin",
		"icon_path": "res://assets/blue_boat.png"
	},
	"gulet": {
		"name": "Ahşap Akdeniz Guleti",
		"cost": 16,
		"radius_bonus": 22.0,
		"delivery_bonus": 2,
		"desc": "Toplama alanı +22 | Konteyner bonusu +2 coin",
		"icon_path": "res://assets/story/gulet.png"
	},
	"emerald": {
		"name": "Yeşil Eko-Gemi",
		"cost": 24,
		"radius_bonus": 30.0,
		"delivery_bonus": 2,
		"desc": "Toplama alanı +30 | Konteyner bonusu +2 coin",
		"icon_path": "res://assets/vehicles/ship_green.png"
	},
	"coast_guard": {
		"name": "Sahil Güvenlik Botu",
		"cost": 32,
		"radius_bonus": 38.0,
		"delivery_bonus": 3,
		"desc": "Toplama alanı +38 | Konteyner bonusu +3 coin",
		"icon_path": "res://assets/story/coast_guard.png"
	},
	"sub_fat": {
		"name": "Mavi Derinlik Denizaltısı",
		"cost": 42,
		"radius_bonus": 46.0,
		"delivery_bonus": 4,
		"desc": "Ağır temizlik denizaltısı | +46 Alan, +4 Coin",
		"icon_path": "res://assets/vehicles/sub_fat.png"
	},
	"sub_green": {
		"name": "Yeşil Eko-Denizaltı",
		"cost": 52,
		"radius_bonus": 54.0,
		"delivery_bonus": 5,
		"desc": "Elektrikli sessiz denizaltı | +54 Alan, +5 Coin",
		"icon_path": "res://assets/vehicles/sub_green.png"
	},
	# Eski kayıtlara tam uyumluluk takma adları:
	"gold": {
		"name": "Sahil Güvenlik Botu",
		"cost": 28,
		"radius_bonus": 38.0,
		"delivery_bonus": 3,
		"desc": "Toplama alanı +38 | Konteyner bonusu +3 coin",
		"icon_path": "res://assets/story/coast_guard.png"
	},
	"royal": {
		"name": "Mavi Derinlik Denizaltısı",
		"cost": 40,
		"radius_bonus": 46.0,
		"delivery_bonus": 4,
		"desc": "Ağır temizlik denizaltısı | +46 Alan, +4 Coin",
		"icon_path": "res://assets/vehicles/sub_fat.png"
	}
}

const BOAT_ORDER := [
	"red", "blue", "gulet", "emerald",
	"coast_guard", "sub_basic", "sub_fat", "sub_green"
]

const LEVEL_STORIES := {
	1: {
		"title": "Kaleiçi Koyu — Sabah Nöbeti",
		"badge": "🏝️ Kıyı Temizliği",
		"speaker": "Dalgıç Deniz",
		"text": "Kaptan, fırtına sonrası kıyı sığlığına tonlarca plastik atık ve cam şişe yığıldı. Kıyı kooperatifi olarak ilk temizliği başlatalım! Çöpleri toplayıp konteynere ulaştır, yüzen balıklara çarpmamaya dikkat et!",
		"objective": "Kıyıdaki plastik ve cam atıkları topla, konteynere boşalt."
	},
	2: {
		"title": "Resif Sığlığı — Kargo Gemisi Kazası",
		"badge": "🚢 Gemi Kazası & Sızıntı",
		"speaker": "Dalgıç Deniz",
		"text": "Acil durum çağrısı! Açıklarda dev bir konteyner gemisi resife çarptı! Denize ağır araç lastikleri ve kimyasal şişeler saçıldı. Balık sürülerini koruyarak dökülen yükleri topla!",
		"objective": "Gemi kazasından yayılan lastikleri ve atıkları arındır."
	},
	3: {
		"title": "Korsan Koyu — Hayalet Ağlar & Carettalar",
		"badge": "🐢 Caretta Kurtarma",
		"speaker": "Dalgıç Deniz",
		"text": "Tarihi batığın etrafındaki terk edilmiş hayalet ağlar sevimli Caretta Carettaları hapsetti! Yanlarına yanaşıp ağları çöz, onları özgürlüğüne kavuştur!",
		"objective": "Ağa takılı Carettaları kurtar, derin suları arındır."
	},
	4: {
		"title": "Derin Kanal — Zehirli Varil Krizi",
		"badge": "☣️ Toksik Varil Sızıntısı",
		"speaker": "Dalgıç Deniz",
		"text": "Alarm! Denizaltı rotasındaki derin kanala kaçak zehirli atık varilleri ve petrol balçığı sızmış! Kirlilik tehlikeli boyutta, denizaltına emisyonsuz elektrikli tahrik takmayı unutma!",
		"objective": "Zehirli varilleri ve petrol balçıklarını topla, emisyonu sıfırla."
	},
	5: {
		"title": "Mavi Dönüş — Büyük Akdeniz Zaferi",
		"badge": "🌊 Nihai Okyanus Dönüşümü",
		"speaker": "Dalgıç Deniz",
		"text": "Büyük Mavi Dönüş günündeyiz! Tüm filomuz devrede. Körfezi son kirlilik noktasına kadar arındırıp Akdeniz'e mavi geleceğini hediye edelim!",
		"objective": "Son atıkları temizle, Akdeniz'i mavi geleceğine kavuştur!"
	}
}

# --- KALICI VERİLER (Save / Load ile saklanır) ---
var coins := 0
var unlocked_level := 1
var current_round := 1
var owned_boats: Array[String] = ["red", "sub_basic"]
var selected_boat := "red"
var has_solar := false
var has_wide_net := false
var has_dive_collector := false
var has_clean_drive := false
var delivered_trash := 0
var total_collected_trash := 0
var rescued_turtles := 0
var level_history: Dictionary = {}
var quests: Array[Dictionary] = []

# --- ANLIK / SEVİYE BAZLI DEĞİŞKENLER ---
var pollution := 50.0
var trash_pollution := 50.0
var motor_pollution := 0.0
var remaining_trash := 15
var initial_trash_unit_pollution := 7.0

var emission_per_sec := 1.50
var carried_trash := 0

var trash_value := -4.0
var turtle_value := -10.0
var fish_penalty := 5.0

var boat_speed := 220.0
var pickup_radius := 40.0
var round_time := 60.0
var running := false
var game_over := false


func _ready() -> void:
	_init_default_quests()
	load_game()


func _init_default_quests() -> void:
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
			"title": "Temiz Enerji: Emisyonsuz tahrik edin",
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


# --- KAYIT VE YÜKLEME SİSTEMİ ---
func save_game() -> void:
	var quest_states: Array[Dictionary] = []
	for q in quests:
		quest_states.append({
			"id": q["id"],
			"progress": int(q["progress"]),
			"completed": bool(q["completed"])
		})

	var data := {
		"coins": coins,
		"unlocked_level": unlocked_level,
		"current_round": current_round,
		"owned_boats": owned_boats,
		"selected_boat": selected_boat,
		"has_solar": has_solar,
		"has_wide_net": has_wide_net,
		"has_dive_collector": has_dive_collector,
		"has_clean_drive": has_clean_drive,
		"delivered_trash": delivered_trash,
		"total_collected_trash": total_collected_trash,
		"rescued_turtles": rescued_turtles,
		"level_history": level_history,
		"quest_states": quest_states
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_str := JSON.stringify(data, "\t")
		file.store_string(json_str)
		file.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		recalculate_pickup_radius()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var text := file.get_as_text()
	file.close()

	var test_json_conv := JSON.new()
	var error := test_json_conv.parse(text)
	if error != OK:
		return

	var data: Dictionary = test_json_conv.data
	if data == null:
		return

	coins = int(data.get("coins", 0))
	unlocked_level = clampi(int(data.get("unlocked_level", 1)), 1, 5)
	current_round = clampi(int(data.get("current_round", 1)), 1, 5)

	var raw_boats = data.get("owned_boats", ["red"])
	owned_boats.clear()
	for b in raw_boats:
		# Katalogdan kaldırılan araçlar (örn. drill_robot) eski kayıtlarda kalmış olabilir
		if BOAT_CATALOG.has(str(b)):
			owned_boats.append(str(b))
	if not ("red" in owned_boats):
		owned_boats.append("red")
	if not ("sub_basic" in owned_boats):
		owned_boats.append("sub_basic")

	selected_boat = str(data.get("selected_boat", "red"))
	if not (selected_boat in owned_boats):
		selected_boat = "red"

	has_solar = bool(data.get("has_solar", false))
	has_wide_net = bool(data.get("has_wide_net", false))
	has_dive_collector = bool(data.get("has_dive_collector", false))
	has_clean_drive = bool(data.get("has_clean_drive", false))
	delivered_trash = int(data.get("delivered_trash", 0))
	total_collected_trash = int(data.get("total_collected_trash", 0))
	rescued_turtles = int(data.get("rescued_turtles", 0))
	level_history = data.get("level_history", {})

	var saved_quests = data.get("quest_states", [])
	if saved_quests is Array:
		for sq in saved_quests:
			var sid = str(sq.get("id", ""))
			for q in quests:
				if q["id"] == sid:
					q["progress"] = int(sq.get("progress", 0))
					q["completed"] = bool(sq.get("completed", false))

	ensure_level_vehicle()
	recalculate_pickup_radius()
	update_emission_for_current_round()
	coins_changed.emit(coins)
	boat_changed.emit(selected_boat)
	quests_changed.emit()


func reset_all_data() -> void:
	coins = 0
	unlocked_level = 1
	current_round = 1
	owned_boats = ["red", "sub_basic"]
	selected_boat = "red"
	has_solar = false
	has_wide_net = false
	has_dive_collector = false
	has_clean_drive = false
	delivered_trash = 0
	total_collected_trash = 0
	rescued_turtles = 0
	level_history.clear()
	_init_default_quests()

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

	recalculate_pickup_radius()
	update_emission_for_current_round()
	coins_changed.emit(coins)
	boat_changed.emit(selected_boat)
	quests_changed.emit()
	save_game()


func record_level_result(level: int, passed: bool) -> void:
	var l_str := str(level)
	if not level_history.has(l_str):
		level_history[l_str] = {"passed": false, "attempts": 0}

	level_history[l_str]["attempts"] = int(level_history[l_str].get("attempts", 0)) + 1
	if passed:
		level_history[l_str]["passed"] = true
		if level >= unlocked_level and unlocked_level < 5:
			unlocked_level = level + 1
	else:
		if not level_history[l_str].has("passed"):
			level_history[l_str]["passed"] = false

	save_game()


# --- OYUN SEVİYE YÖNETİMİ ---
func get_round_time() -> float:
	match current_round:
		1: return 60.0
		2: return 55.0
		3: return 52.0
		4: return 48.0
		_: return 45.0


func get_min_pollution_for_level(level: int) -> float:
	match level:
		1: return 50.0
		2: return 52.0
		3: return 56.0
		4: return 58.0
		_: return 60.0


func update_emission_for_current_round() -> void:
	if has_clean_propulsion():
		emission_per_sec = 0.0
	else:
		emission_per_sec = 1.50 + (current_round - 1) * 0.15


func recalculate_pickup_radius() -> void:
	var base := 40.0
	if has_collection_upgrade():
		base += 25.0
	if BOAT_CATALOG.has(selected_boat):
		base += float(BOAT_CATALOG[selected_boat]["radius_bonus"])
	pickup_radius = base


func start_level_round(lvl: int) -> void:
	current_round = clampi(lvl, 1, 5)
	ensure_level_vehicle()
	round_time = get_round_time()
	update_emission_for_current_round()
	recalculate_pickup_radius()
	carried_trash = 0
	running = false
	game_over = false
	start_level_pollution(15, 7)
	carried_trash_changed.emit(carried_trash, delivered_trash)
	save_game()


func start_next_level() -> void:
	if current_round < 5:
		current_round += 1
		unlocked_level = maxi(unlocked_level, current_round)
	ensure_level_vehicle()
	recalculate_pickup_radius()
	round_time = get_round_time()
	update_emission_for_current_round()
	carried_trash = 0
	save_game()


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


func is_sea_clean() -> bool:
	# Kalan sayısı henüz üretilmemiş çöpleri de içerir.
	return remaining_trash == 0


func get_current_emission_rate() -> float:
	return 0.0 if has_clean_propulsion() or is_sea_clean() else emission_per_sec


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
	save_game()
	return bonus_coins


func record_turtle_rescue() -> void:
	rescued_turtles += 1
	_update_quests()
	save_game()


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
				q["progress"] = 1 if has_solar or has_clean_drive else 0

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
		save_game()


func get_active_quest_summary() -> String:
	for q in quests:
		if not q["completed"]:
			return "%s (%d/%d)" % [
				q["title"],
				int(q["progress"]),
				int(q["target"])
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
	if game_over or is_sea_clean():
		return

	if amount >= 0.0:
		motor_pollution += amount
		_update_pollution()
	else:
		clean_motor_pollution(-amount)


func _update_pollution() -> void:
	# Son çöp toplandıktan sonra teslimat ve Caretta kurtarma boyunca da %0.
	if is_sea_clean():
		trash_pollution = 0.0
		motor_pollution = 0.0
	pollution = clampf(trash_pollution + motor_pollution, 0.0, 100.0)
	pollution_changed.emit(pollution)

	if pollution >= 100.0 and not game_over:
		game_over = true
		running = false
		game_lost.emit()


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	coins_changed.emit(coins)
	save_game()


func is_boat_owned(boat_id: String) -> bool:
	return boat_id in owned_boats


func buy_or_select_boat(boat_id: String, catalog_purchase: bool = false) -> bool:
	if not BOAT_CATALOG.has(boat_id) or (not catalog_purchase and not is_vehicle_available(boat_id)):
		return false

	if is_boat_owned(boat_id):
		set_boat(boat_id)
		save_game()
		return true

	var cost: int = int(BOAT_CATALOG[boat_id]["cost"])
	if coins < cost:
		return false

	owned_boats.append(boat_id)
	add_coins(-cost)
	set_boat(boat_id)
	save_game()
	return true


func buy_net(mode: int = -1) -> bool:
	var underwater := is_underwater_level() if mode < 0 else mode == 1
	if (has_dive_collector if underwater else has_wide_net) or coins < 8:
		return false
	if underwater:
		has_dive_collector = true
	else:
		has_wide_net = true
	add_coins(-8)
	recalculate_pickup_radius()
	save_game()
	return true


func buy_solar(mode: int = -1) -> bool:
	var underwater := is_underwater_level() if mode < 0 else mode == 1
	if (has_clean_drive if underwater else has_solar) or coins < 15:
		return false
	if underwater:
		has_clean_drive = true
	else:
		has_solar = true
	add_coins(-15)
	update_emission_for_current_round()
	_update_quests()
	save_game()
	return true


func set_boat(boat_id: String) -> void:
	if not is_vehicle_available(boat_id) or not is_boat_owned(boat_id):
		return
	selected_boat = boat_id
	recalculate_pickup_radius()
	boat_changed.emit(selected_boat)
	save_game()


func is_underwater_level() -> bool:
	return current_round >= 3


func is_vehicle_available(boat_id: String) -> bool:
	var submarine := boat_id in ["sub_basic", "sub_fat", "sub_green", "royal"]
	return BOAT_CATALOG.has(boat_id) and submarine == is_underwater_level()


func ensure_level_vehicle() -> void:
	if is_vehicle_available(selected_boat):
		return
	selected_boat = "sub_basic" if is_underwater_level() else "red"
	for boat_id in owned_boats:
		if is_vehicle_available(boat_id):
			selected_boat = boat_id
	boat_changed.emit(selected_boat)


func has_collection_upgrade() -> bool:
	return has_dive_collector if is_underwater_level() else has_wide_net


func has_clean_propulsion() -> bool:
	return has_clean_drive if is_underwater_level() else has_solar


func get_collection_equipment_name() -> String:
	return "Dalgıç Toplama Aparatı" if is_underwater_level() else "Geniş Ağ"


func get_propulsion_equipment_name() -> String:
	return "Emisyonsuz Elektrikli Tahrik" if is_underwater_level() else "Güneş Paneli"


func get_cargo_location_name() -> String:
	return "Denizaltında" if is_underwater_level() else "Teknede"


func get_boat_name(boat_id: String = "") -> String:
	var id := selected_boat if boat_id.is_empty() else boat_id
	if BOAT_CATALOG.has(id):
		return String(BOAT_CATALOG[id]["name"])
	return "Kırmızı Balıkçı Teknesi"


func show_toast(message: String, duration: float = 3.0) -> void:
	toast_requested.emit(message, duration)
