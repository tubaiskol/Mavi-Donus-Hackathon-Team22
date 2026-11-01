extends Node

## Mavi Dönüş — Ses Yöneticisi (AudioManager)
## Tüm ses efektlerini ve arka plan deniz ambiyansını yönetir.

const SFX_DIR := "res://assets/audio/"

var sounds: Dictionary = {}
var sfx_players: Array[AudioStreamPlayer] = []
const POOL_SIZE := 8

var ambient_player: AudioStreamPlayer
var engine_player: AudioStreamPlayer
var warning_player: AudioStreamPlayer

var last_engine_was_solar := false
var music_volume := 80.0
var sfx_volume := 85.0
var _last_pollution := 50.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# SFX AudioStreamPlayer havuzu (aynı anda birden çok çöp toplandığında ses kesilmesin diye)
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		sfx_players.append(p)

	# Deniz ambiyansı çalıcısı
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = &"Master"
	add_child(ambient_player)

	# Motor sesi çalıcısı
	engine_player = AudioStreamPlayer.new()
	engine_player.bus = &"Master"
	add_child(engine_player)

	# Kirlilik kritik uyarı çalıcısı
	warning_player = AudioStreamPlayer.new()
	warning_player.bus = &"Master"
	add_child(warning_player)

	_load_sounds()

	# GameState sinyallerine otomatik bağlan
	if Engine.has_singleton("GameState") or has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		if gs:
			gs.game_won.connect(_on_game_won)
			gs.game_lost.connect(_on_game_lost)
			gs.round_ended.connect(_on_round_ended)
			gs.pollution_changed.connect(_on_pollution_changed)

	start_ambient()


func _load_sounds() -> void:
	var sound_files := {
		"trash_pickup": "sfx_trash_pickup.wav",
		"toxic_pickup": "sfx_toxic_pickup.wav",
		"turtle_rescue": "sfx_turtle_rescue.wav",
		"turtle_pulse": "sfx_turtle_pulse.wav",
		"shop_buy": "sfx_shop_buy.wav",
		"solar_activate": "sfx_solar_activate.wav",
		"button_click": "sfx_button_click.wav",
		"level_complete": "sfx_level_complete.wav",
		"game_over": "sfx_game_over.wav",
		"pollution_warning": "sfx_pollution_warning.wav",
		"boat_engine_diesel": "sfx_boat_engine_diesel.wav",
		"boat_engine_solar": "sfx_boat_engine_solar.wav",
		"fish_hit": "sfx_fish_hit.wav",
		"win": "sfx_win.wav",
		"ambient_ocean": "ambient_ocean_loop.wav"
	}

	for s_key in sound_files:
		var path: String = SFX_DIR + sound_files[s_key]
		if ResourceLoader.exists(path):
			sounds[s_key] = load(path)


func _sfx_offset_db() -> float:
	if sfx_volume <= 1.0:
		return -80.0
	return linear_to_db(clampf(sfx_volume / 100.0, 0.01, 1.0))


func _music_offset_db() -> float:
	if music_volume <= 1.0:
		return -80.0
	return linear_to_db(clampf(music_volume / 100.0, 0.01, 1.0))


func set_music_volume(val: float) -> void:
	music_volume = clampf(val, 0.0, 100.0)
	set_ambient_volume_for_pollution(_last_pollution)


func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 100.0)
	if sfx_volume <= 1.0:
		stop_engine()


func play(sound_name: String, pitch_range: float = 0.05, volume_db: float = 0.0) -> void:
	if sfx_volume <= 1.0:
		return
	if not sounds.has(sound_name):
		return

	var stream: AudioStream = sounds[sound_name]
	if stream == null:
		return

	var final_db := volume_db + _sfx_offset_db()

	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = final_db
			if pitch_range > 0.0:
				p.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
			else:
				p.pitch_scale = 1.0
			p.play()
			return

	# Havuz doluysa ilkini ez
	var fallback := sfx_players[0]
	fallback.stream = stream
	fallback.volume_db = final_db
	fallback.pitch_scale = 1.0
	fallback.play()


# --- KULLANIŞLI KISAYOL FONKSİYONLARI ---

func play_trash() -> void:
	play("trash_pickup", 0.08, 0.0)

func play_toxic() -> void:
	play("toxic_pickup", 0.06, 2.0)

func play_turtle() -> void:
	play("turtle_rescue", 0.0, 3.0)

func play_turtle_pulse() -> void:
	play("turtle_pulse", 0.04, -2.0)

func play_buy() -> void:
	play("shop_buy", 0.0, 1.0)

func play_solar() -> void:
	play("solar_activate", 0.0, 2.0)

func play_fish_hit() -> void:
	play("fish_hit", 0.08, 1.0)

func play_button() -> void:
	play("button_click", 0.05, -1.0)

func play_win() -> void:
	play("level_complete", 0.0, 2.0)

func play_lose() -> void:
	play("game_over", 0.0, 3.0)


# --- AMBİYANS VE MOTOR YÖNETİMİ ---

func start_ambient() -> void:
	if sounds.has("ambient_ocean") and not ambient_player.playing:
		ambient_player.stream = sounds["ambient_ocean"]
		set_ambient_volume_for_pollution(_last_pollution)
		ambient_player.play()


func set_ambient_volume_for_pollution(pollution: float) -> void:
	_last_pollution = pollution
	if music_volume <= 1.0:
		ambient_player.volume_db = -80.0
		return
	var norm := clampf(pollution / 100.0, 0.0, 1.0)
	ambient_player.volume_db = lerpf(-4.0, -14.0, norm) + _music_offset_db()


func start_engine(is_solar: bool) -> void:
	if sfx_volume <= 1.0:
		stop_engine()
		return
	last_engine_was_solar = is_solar
	var sound_key := "boat_engine_solar" if is_solar else "boat_engine_diesel"
	if sounds.has(sound_key):
		engine_player.stream = sounds[sound_key]
		engine_player.volume_db = (-8.0 if is_solar else -5.0) + _sfx_offset_db()
		if not engine_player.playing:
			engine_player.play()


func stop_engine() -> void:
	engine_player.stop()


# --- OTOMATİK SİNYAL TEPKİLERİ ---

func _on_game_won() -> void:
	play_win()
	stop_engine()

func _on_game_lost() -> void:
	play_lose()
	stop_engine()

func _on_round_ended() -> void:
	play_win()
	stop_engine()

func _on_pollution_changed(value: float) -> void:
	set_ambient_volume_for_pollution(value)
	if sfx_volume > 1.0 and value >= 85.0 and not warning_player.playing:
		if sounds.has("pollution_warning"):
			warning_player.stream = sounds["pollution_warning"]
			warning_player.volume_db = 1.0 + _sfx_offset_db()
			warning_player.play()
