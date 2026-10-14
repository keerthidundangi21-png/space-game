extends Node2D

# K20: Alien Survival - Godot 4 playable prototype
# Everything is drawn with vector shapes so the project runs without external assets.

const W := 1280.0
const H := 720.0
const SAVE_PREFIX := "user://k20_profile_"

enum Screen { MENU, HOW_TO_PLAY, PROFILE, HEROES, PLANETS, STORY, GAME, GAME_OVER, WIN }
var screen: Screen = Screen.MENU

var heroes := [
	{"name":"VOLT","kind":"ASSAULT","color":Color("#36d9ff"),"hp":120},
	{"name":"AXEL","kind":"HEAVY","color":Color("#ffb84d"),"hp":160},
	{"name":"KAI","kind":"SCOUT","color":Color("#8af56a"),"hp":110},
	{"name":"REX","kind":"SNIPER","color":Color("#d7e5ff"),"hp":100},
	{"name":"SHADOW","kind":"STEALTH","color":Color("#b48cff"),"hp":115},
	{"name":"LUNA","kind":"TECH","color":Color("#ff79ce"),"hp":110},
	{"name":"SERA","kind":"BLADE","color":Color("#ff8e9c"),"hp":125},
	{"name":"NOVA","kind":"ENERGY","color":Color("#45d9ff"),"hp":115},
	{"name":"ZARA","kind":"RANGER","color":Color("#ffd47a"),"hp":120},
	{"name":"VEX","kind":"VOID","color":Color("#c879ff"),"hp":130}
]
var planets: Array[Dictionary] = []
var planet_page := 0
var unlocked_planets := 1
var planet_names := [
 "ZORAX", "VULCAN", "KRYON", "NEBULA", "VERDANT", "TITAN", "ECLIPSE", "ABYSS", "PYRUS", "OMEGA",
 "AURORA", "DREADMOON", "CINDRA", "FROSTVEIL", "MIRIDIAN", "THORN", "RADIANT", "GRAVEMARCH", "NEXUS", "OBLIVION",
 "EMBERFALL", "GLACIER-9", "VORTEX", "MOSSHEART", "STARFORGE", "NIGHTREACH", "IONIS", "CRIMSON DEEP", "SKYSHARD", "VOIDWELL",
 "ASHEN PRIME", "POLARIS", "VENOMARA", "DUSKARA", "IRONWRAITH", "SOLARA", "BLACK COMET", "ECHO-7", "RIFTWORLD", "BLOODSTAR",
 "QUANTARA", "DEAD ORBIT", "STORMHOLD", "XENITH", "LAST EDEN", "DARK NEBULA", "HELLION", "ARKTOS", "SINGULARITY", "OVERLORD'S THRONE"
]
var planet_descs := ["THE LOST FRONTIER", "RIVERS OF FIRE", "FROZEN WASTELAND", "CRYSTAL NIGHT", "TOXIC WILDS", "BROKEN COLOSSUS", "THE DARK SIDE", "VOID STORM", "INFERNO CORE", "ALIEN OVERLORD"]
var planet_colors := [Color("#2e9fff"),Color("#ff633e"),Color("#72dcff"),Color("#bd6bff"),Color("#6cf16b"),Color("#e4ad6b"),Color("#9189ff"),Color("#ff66a9"),Color("#ff4d38"),Color("#f34bff")]
func _build_planets() -> void:
	planets.clear()
	for i in range(50):
		var difficulty: String
		if i < 10:
			difficulty = "EASY"
		elif i < 20:
			difficulty = "MEDIUM"
		elif i < 35:
			difficulty = "HARD"
		else:
			difficulty = "EXTREME"
		var desc: String = planet_descs[i % planet_descs.size()]
		var col: Color = planet_colors[i % planet_colors.size()]
		planets.append({
			"name": planet_names[i],
			"desc": desc,
			"color": col,
			"difficulty": difficulty
		})

var selected_hero := 0
var selected_planet := 0
var profile_name := "PLAYER 1"
var profile_slot := 0
var story_page := 0
var story_seen := false

var player_pos := Vector2(120, 505)
var player_vel := Vector2.ZERO
var player_hp := 120.0
var lives := 3
var score := 0
var coins := 0
var weapon_level := 1
var weapon_type := 0
var weapon_names := ["PULSE RIFLE", "LASER CANNON", "PLASMA BLASTER", "ROCKET LAUNCHER"]
var weapon_damage := [17.0, 24.0, 34.0, 58.0]
var weapon_cooldowns := [0.22, 0.38, 0.52, 0.78]
var kills := 0
var facing := 1
var on_ground := false
var invulnerable := 0.0
var shoot_cooldown := 0.0
var world_scroll := 0.0
var level_length := 3400.0
var platforms: Array[Rect2] = []
var hazards: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var boss: Dictionary = {}
var game_message := ""
var message_timer := 0.0
var save_data := {}
var gameplay_art: Texture2D
var hero_textures: Array[Texture2D] = []
var background_texture: Texture2D
var mini_alien_art: Texture2D
var boss_alien_art: Texture2D
var music_player: AudioStreamPlayer
var music_enabled := true
# Combat feedback systems: hit-stop, screen shake, impact sparks, damage numbers and kill combos.
var screen_shake := 0.0
var hitstop := 0.0
var screen_flash := 0.0
var combo_count := 0
var combo_timer := 0.0
var effects: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var enemy_projectiles: Array[Dictionary] = []
var boss_fire_timer := 1.2
var boss_phase := 1
var total_kills := 0
var hero_kills := [0,0,0,0,0,0,0,0,0,0]
var sfx_players: Dictionary = {}

# Mobile touch controls.
var touch_left := false
var touch_right := false
var touch_shoot := false
var touch_jump := false
var active_touches: Dictionary = {}
var wave_spawn_timer := 3.0

func _ready() -> void:
	_build_planets()
	gameplay_art = load("res://assets/k20_game_art.png")
	hero_textures.clear()
	for hero_asset in ["volt", "axel", "kai", "rex", "shadow", "luna", "sera", "nova", "zara", "vex"]:
		hero_textures.append(load("res://assets/heroes/" + hero_asset + ".png"))
	background_texture = load("res://assets/k20_background.png")
	mini_alien_art = load("res://assets/monster_mini.png")
	boss_alien_art = load("res://assets/monster_boss.png")
	music_player = AudioStreamPlayer.new()
	music_player.name = "K20_Background_Music"
	var music_stream := load("res://assets/k20_background_music.mp3")
	if music_stream is AudioStreamMP3:
		music_stream.loop = true
	music_player.stream = music_stream
	music_player.volume_db = -15.0
	add_child(music_player)
	music_player.play()
	randomize()
	for sound_name in ["shot", "laser", "hit", "kill", "boss", "coin", "hurt", "upgrade"]:
		var player := AudioStreamPlayer.new()
		player.name = "SFX_" + sound_name
		player.stream = load("res://assets/sfx_" + sound_name + ".wav")
		player.volume_db = -2.0
		add_child(player)
		sfx_players[sound_name] = player
	_load_save()
	set_process(true)
	set_process_input(true)

func _process(delta: float) -> void:
	if screen == Screen.GAME:
		if hitstop > 0.0:
			hitstop = maxf(0.0, hitstop - delta)
		else:
			_update_game(delta)
	if message_timer > 0.0:
		message_timer = maxf(0.0, message_timer - delta)
	if screen_shake > 0.0:
		screen_shake = maxf(0.0, screen_shake - delta * 2.8)
	if screen_flash > 0.0:
		screen_flash = maxf(0.0, screen_flash - delta * 2.5)
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_count = 0
	_update_combat_fx(delta)
	queue_redraw()

func _input(event: InputEvent) -> void:
	# Convert screen coordinates to the game's 1280x720 canvas coordinates.
	if event is InputEventScreenTouch:
		var touch_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if screen == Screen.GAME:
			if event.pressed:
				var control := ""
				if Rect2(35, 565, 95, 110).has_point(touch_pos):
					control = "left"
				elif Rect2(135, 565, 95, 110).has_point(touch_pos):
					control = "right"
				elif Rect2(250, 555, 130, 125).has_point(touch_pos):
					control = "jump"
				elif Rect2(1090, 555, 150, 125).has_point(touch_pos):
					control = "shoot"
				elif Rect2(955, 465, 120, 75).has_point(touch_pos):
					control = "upgrade"
					_upgrade_weapon()
				active_touches[event.index] = control
			else:
				active_touches.erase(event.index)
			_update_touch_states()
		else:
			if event.pressed:
				_click(touch_pos)
		return
	if event is InputEventScreenDrag and screen == Screen.GAME:
		var drag_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var control := ""
		if Rect2(35, 565, 95, 110).has_point(drag_pos):
			control = "left"
		elif Rect2(135, 565, 95, 110).has_point(drag_pos):
			control = "right"
		elif Rect2(1090, 555, 150, 125).has_point(drag_pos):
			control = "shoot"
		elif Rect2(250, 555, 130, 125).has_point(drag_pos):
			control = "jump"
		active_touches[event.index] = control
		_update_touch_states()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			screen = Screen.MENU
			active_touches.clear()
			_update_touch_states()
			return
		if screen == Screen.GAME:
			if event.keycode == KEY_M:
				music_enabled = not music_enabled
				if music_player:
					music_player.stream_paused = not music_enabled
				_notify("BACKGROUND MUSIC " + ("ON" if music_enabled else "OFF"))
			if event.keycode == KEY_SPACE or event.keycode == KEY_W or event.keycode == KEY_UP:
				_jump()
			if event.keycode == KEY_F or event.keycode == KEY_ENTER:
				_shoot()
			if event.keycode == KEY_E:
				_upgrade_weapon()
			if event.keycode == KEY_1:
				_select_weapon(0)
			if event.keycode == KEY_2:
				_select_weapon(1)
			if event.keycode == KEY_3:
				_select_weapon(2)
			if event.keycode == KEY_4:
				_select_weapon(3)
		elif screen == Screen.STORY and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			story_page += 1
			if story_page > 2:
				story_seen = true
				_save_game()
				_start_level()
		elif screen == Screen.GAME_OVER or screen == Screen.WIN:
			if event.keycode == KEY_ENTER:
				screen = Screen.PLANETS if screen == Screen.WIN else Screen.GAME
				if screen == Screen.GAME:
					_start_level()
		elif screen == Screen.MENU:
			if event.keycode == KEY_ENTER:
				screen = Screen.HOW_TO_PLAY
		elif screen == Screen.HOW_TO_PLAY or screen == Screen.PROFILE:
			if event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
				screen = Screen.HEROES if screen == Screen.HOW_TO_PLAY else Screen.MENU
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(get_global_transform_with_canvas().affine_inverse() * event.position)

func _update_touch_states() -> void:
	touch_left = false
	touch_right = false
	touch_shoot = false
	touch_jump = false
	for control in active_touches.values():
		if control == "left":
			touch_left = true
		elif control == "right":
			touch_right = true
		elif control == "shoot":
			touch_shoot = true
		elif control == "jump":
			touch_jump = true

func _click(p: Vector2) -> void:
	if screen == Screen.MENU:
		if Rect2(42, 174, 350, 42).has_point(p):
			profile_slot = (profile_slot + 1) % 3
			profile_name = "PLAYER " + str(profile_slot + 1)
			_load_save()
			_notify(profile_name + " SELECTED")
		elif Rect2(470, 390, 340, 54).has_point(p):
			screen = Screen.HOW_TO_PLAY
		elif Rect2(470, 452, 340, 48).has_point(p):
			screen = Screen.STORY
			story_page = 0
		elif Rect2(470, 508, 340, 48).has_point(p):
			screen = Screen.PROFILE
		elif Rect2(470, 564, 340, 48).has_point(p):
			var loaded := _load_save()
			screen = Screen.HEROES
			if loaded:
				_notify("SAVED PROFILE LOADED: " + profile_name)
			else:
				_notify("EMPTY SLOT: " + profile_name + " - NEW GAME")
	elif screen == Screen.HOW_TO_PLAY:
		if Rect2(900, 620, 320, 60).has_point(p):
			screen = Screen.HEROES
		elif Rect2(40, 620, 180, 60).has_point(p):
			screen = Screen.MENU
	elif screen == Screen.PROFILE:
		if Rect2(1000, 630, 220, 56).has_point(p):
			screen = Screen.MENU
		elif Rect2(40, 630, 180, 56).has_point(p):
			profile_slot = (profile_slot + 1) % 3
			profile_name = "PLAYER " + str(profile_slot + 1)
			_load_save()
			_notify("SWITCHED TO " + profile_name)
	elif screen == Screen.HEROES:
		for i in range(10):
			var x := 42.0 + float(i % 5) * 244.0
			var y := 120.0 + float(i / 5) * 220.0
			if Rect2(x, y, 220, 190).has_point(p):
				selected_hero = i
				_notify(heroes[i]["name"] + " SELECTED")
				return
		if Rect2(1000, 630, 220, 56).has_point(p):
			screen = Screen.PLANETS
		elif Rect2(40, 630, 180, 56).has_point(p):
			screen = Screen.MENU
	elif screen == Screen.PLANETS:
		for i in range(10):
			var x := 36.0 + float(i % 5) * 244.0
			var y := 120.0 + float(i / 5) * 220.0
			if Rect2(x, y, 220, 190).has_point(p):
				var planet_index := planet_page * 10 + i
				if planet_index < unlocked_planets:
					selected_planet = planet_index
					_notify("PLANET " + str(planet_index+1) + " SELECTED")
				else:
					_notify("LOCKED! CLEAR PLANET " + str(planet_index) + " FIRST")
				return
		if Rect2(260, 630, 180, 56).has_point(p):
			planet_page = maxi(0, planet_page - 1)
		if Rect2(470, 630, 180, 56).has_point(p):
			planet_page = mini(4, planet_page + 1)
		if Rect2(1000, 630, 220, 56).has_point(p):
			if story_seen:
				_start_level()
			else:
				screen = Screen.STORY
				story_page = 0
		if Rect2(40, 630, 180, 56).has_point(p):
			screen = Screen.HEROES
	elif screen == Screen.STORY:
		if Rect2(700, 620, 220, 60).has_point(p):
			story_seen = true
			_save_game()
			_start_level()
		elif Rect2(950, 620, 270, 60).has_point(p):
			story_page += 1
			if story_page > 2:
				story_seen = true
				_save_game()
				_start_level()
	elif screen == Screen.GAME_OVER:
		if Rect2(490, 475, 300, 60).has_point(p):
			_start_level()
	elif screen == Screen.WIN:
		if Rect2(490, 475, 300, 60).has_point(p):
			selected_planet = mini(49, selected_planet + 1)
			planet_page = selected_planet / 10
			screen = Screen.PLANETS

func _start_level() -> void:
	screen = Screen.GAME
	player_pos = Vector2(95, 478)
	player_vel = Vector2.ZERO
	player_hp = float(heroes[selected_hero]["hp"])
	lives = 3
	score = 0
	kills = 0
	facing = 1
	invulnerable = 0.0
	shoot_cooldown = 0.0
	world_scroll = 0.0
	level_length = 1280.0
	platforms.clear()
	hazards.clear()
	enemies.clear()
	bullets.clear()
	pickups.clear()
	effects.clear()
	floating_texts.clear()
	enemy_projectiles.clear()
	boss.clear()
	screen_shake = 0.0
	hitstop = 0.0
	screen_flash = 0.0
	combo_count = 0
	combo_timer = 0.0
	boss_fire_timer = 1.2
	boss_phase = 1
	platforms.append(Rect2(0, 478, level_length, 220))
	# Each planet gets a different platform and hazard layout, while keeping the same safe start.
	var layout := selected_planet % 5
	if layout == 0:
		platforms.append(Rect2(210, 345, 250, 18))
		platforms.append(Rect2(590, 420, 250, 18))
		platforms.append(Rect2(880, 420, 180, 18))
		platforms.append(Rect2(1050, 465, 220, 18))
		hazards = [{"x":350.0,"y":458.0,"w":92.0,"h":14.0,"type":"SPIKES"},{"x":520.0,"y":458.0,"w":85.0,"h":14.0,"type":"LAVA"},{"x":700.0,"y":458.0,"w":80.0,"h":14.0,"type":"SPIKES"},{"x":970.0,"y":458.0,"w":85.0,"h":14.0,"type":"POISON"}]
	elif layout == 1:
		platforms.append(Rect2(180, 405, 170, 18))
		platforms.append(Rect2(410, 330, 190, 18))
		platforms.append(Rect2(680, 390, 170, 18))
		platforms.append(Rect2(930, 315, 200, 18))
		hazards = [{"x":300.0,"y":458.0,"w":110.0,"h":14.0,"type":"LAVA"},{"x":560.0,"y":458.0,"w":95.0,"h":14.0,"type":"ELECTRIC"},{"x":810.0,"y":458.0,"w":105.0,"h":14.0,"type":"SPIKES"},{"x":1080.0,"y":458.0,"w":80.0,"h":14.0,"type":"POISON"}]
	elif layout == 2:
		platforms.append(Rect2(230, 370, 150, 18))
		platforms.append(Rect2(440, 430, 190, 18))
		platforms.append(Rect2(690, 350, 180, 18))
		platforms.append(Rect2(950, 405, 210, 18))
		hazards = [{"x":370.0,"y":458.0,"w":100.0,"h":14.0,"type":"POISON"},{"x":610.0,"y":458.0,"w":95.0,"h":14.0,"type":"VOID"},{"x":850.0,"y":458.0,"w":100.0,"h":14.0,"type":"LAVA"}]
	elif layout == 3:
		platforms.append(Rect2(160, 430, 180, 18))
		platforms.append(Rect2(390, 360, 160, 18))
		platforms.append(Rect2(620, 300, 180, 18))
		platforms.append(Rect2(860, 370, 160, 18))
		platforms.append(Rect2(1060, 420, 170, 18))
		hazards = [{"x":340.0,"y":458.0,"w":90.0,"h":14.0,"type":"ELECTRIC"},{"x":550.0,"y":458.0,"w":90.0,"h":14.0,"type":"SPIKES"},{"x":790.0,"y":458.0,"w":100.0,"h":14.0,"type":"VOID"},{"x":1020.0,"y":458.0,"w":90.0,"h":14.0,"type":"LAVA"}]
	else:
		platforms.append(Rect2(190, 350, 210, 18))
		platforms.append(Rect2(460, 400, 150, 18))
		platforms.append(Rect2(660, 325, 210, 18))
		platforms.append(Rect2(920, 385, 150, 18))
		hazards = [{"x":400.0,"y":458.0,"w":105.0,"h":14.0,"type":"LAVA"},{"x":620.0,"y":458.0,"w":90.0,"h":14.0,"type":"ELECTRIC"},{"x":870.0,"y":458.0,"w":100.0,"h":14.0,"type":"POISON"},{"x":1080.0,"y":458.0,"w":90.0,"h":14.0,"type":"SPIKES"}]
	# Add world-specific obstacle pairs so planets don't simply repeat the same five layouts.
	var extra_x := 250.0 + float((selected_planet * 97) % 650)
	var extra_w := 65.0 + float((selected_planet * 13) % 70)
	var hazard_types := ["SPIKES", "LAVA", "ELECTRIC", "POISON", "VOID"]
	hazards.append({"x":extra_x,"y":458.0,"w":extra_w,"h":14.0,"type":hazard_types[selected_planet % hazard_types.size()]})
	var second_x := clampf(extra_x + 170.0 + float((selected_planet * 19) % 120), 300.0, 1080.0)
	hazards.append({"x":second_x,"y":458.0,"w":55.0 + float((selected_planet * 7) % 65),"h":14.0,"type":hazard_types[(selected_planet + 2) % hazard_types.size()]})
	if selected_planet % 2 == 0:
		platforms.append(Rect2(300.0 + float((selected_planet * 43) % 430), 270.0 + float((selected_planet * 17) % 90), 115.0 + float((selected_planet * 11) % 100), 18.0))
	# Enemy positions and counts change by planet sector.
	# Add deterministic planet-specific offsets so even planets sharing a layout feel different.
	for platform_index in range(1, platforms.size()):
		var adjusted_platform: Rect2 = platforms[platform_index]
		adjusted_platform.position.x = clampf(adjusted_platform.position.x + float((selected_planet * 23 + platform_index * 17) % 61) - 30.0, 115.0, 1080.0)
		adjusted_platform.position.y = clampf(adjusted_platform.position.y + float((selected_planet * 11 + platform_index * 7) % 45) - 22.0, 290.0, 445.0)
		platforms[platform_index] = adjusted_platform
	for hazard_index in range(hazards.size()):
		var adjusted_hazard: Dictionary = hazards[hazard_index]
		adjusted_hazard["x"] = clampf(float(adjusted_hazard["x"]) + float((selected_planet * 37 + hazard_index * 19) % 71) - 25.0, 250.0, 1150.0 - float(adjusted_hazard["w"]))
		hazards[hazard_index] = adjusted_hazard
	var enemy_spawns: Array[Dictionary] = []
	var enemy_count := 5 + mini(4, selected_planet / 10)
	for enemy_i in range(enemy_count):
		var ex := clampf(player_pos.x + 185.0 + float(enemy_i) * 105.0, 230.0, 1220.0)
		var flying := ((enemy_i + layout + selected_planet) % 5 == 0)
		var ey := 315.0 if flying else 460.0
		enemy_spawns.append({"x":ex,"y":ey,"flyer":flying})
	for spawn in enemy_spawns:
		var ehp: float = 24.0 + float(selected_planet) * 7.0
		var alien_speed := 70.0 + float(mini(35, selected_planet * 2)) + randf_range(-8.0, 12.0)
		enemies.append({"x":spawn["x"],"y":spawn["y"],"hp":ehp,"maxhp":ehp,"dir":-1.0,"alive":true,"boss":false,"flyer":spawn["flyer"],"phase":randf() * 4.0,"shot_timer":randf_range(1.2,2.4),"speed":alien_speed})
	boss = {"x":1190.0,"y":460.0,"hp":180.0 + selected_planet*40.0,"maxhp":180.0 + selected_planet*40.0,"alive":true,"phase":0.0,"speed":24.0 + float(selected_planet % 6) * 2.0}
	for i in range(12):
		pickups.append({"x":120.0 + i * 92.0,"y":randf_range(350.0, 455.0),"taken":false})
	_notify("MISSION START: " + planets[selected_planet]["name"])
	_save_game()

func _update_game(delta: float) -> void:
	var speed := 285.0
	player_vel.x = 0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or touch_left:
		player_vel.x = -speed
		facing = -1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or touch_right:
		player_vel.x = speed
		facing = 1
	if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or touch_jump:
		if on_ground:
			_jump()
	if Input.is_key_pressed(KEY_F) or Input.is_key_pressed(KEY_ENTER) or touch_shoot:
		_shoot()
	player_vel.y += 1150.0 * delta
	player_pos += player_vel * delta
	on_ground = false
	var pr := Rect2(player_pos.x - 19, player_pos.y - 43, 38, 45)
	for platform in platforms:
		var prev_bottom: float = player_pos.y - player_vel.y * delta + 2.0
		if pr.position.x < platform.end.x and pr.end.x > platform.position.x and prev_bottom <= platform.position.y + 8 and pr.end.y >= platform.position.y and player_vel.y >= 0:
			player_pos.y = platform.position.y - 2
			player_vel.y = 0
			on_ground = true
			pr = Rect2(player_pos.x - 19, player_pos.y - 43, 38, 45)
	player_pos.x = clampf(player_pos.x, 24.0, W - 24.0)
	if player_pos.y > H + 100:
		_hurt(999)
		player_pos.y = 478
	if invulnerable > 0:
		invulnerable -= delta
	if shoot_cooldown > 0:
		shoot_cooldown -= delta
	world_scroll = 0.0
	pr = Rect2(player_pos.x - 18, player_pos.y - 40, 36, 42)
	for hz in hazards:
		var hr := Rect2(hz["x"], hz["y"], hz["w"], hz["h"] + 12)
		if pr.intersects(hr):
			_hurt(22.0 * delta)
			screen_shake = maxf(screen_shake, 0.05)
			screen_flash = maxf(screen_flash, 0.035)
	for e in enemies:
		if not e["alive"]:
			continue
		e["phase"] += delta
		if e.get("flyer", false):
			e["x"] += sin(e["phase"] * 1.8) * 12.0 * delta
		else:
			var chase_dir: float = signf(player_pos.x - float(e["x"]))
			if absf(player_pos.x - float(e["x"])) > 52.0:
				e["x"] += chase_dir * float(e.get("speed", 72.0)) * delta
				e["dir"] = chase_dir
		var er := Rect2(e["x"]-23, e["y"]-34, 46, 36)
		if pr.intersects(er):
			_hurt(26.0 * delta)
	if boss.get("alive", false):
		boss["phase"] += delta
		var boss_dir := signf(player_pos.x - float(boss["x"]))
		if absf(player_pos.x - float(boss["x"])) > 112.0:
			boss["x"] += boss_dir * float(boss.get("speed", 26.0)) * delta
		boss["y"] = 460.0
		if pr.intersects(Rect2(boss["x"]-65, boss["y"]-75, 130, 78)):
			_hurt(38.0 * delta)
	# Surprise waves: spawn two or three ground aliens near the player every few seconds.
	wave_spawn_timer -= delta
	var living_aliens := 0
	for alien in enemies:
		if alien.get("alive", false):
			living_aliens += 1
	if wave_spawn_timer <= 0.0 and living_aliens <= 6:
		var wave_count := randi_range(2, 3)
		for wave_i in range(wave_count):
			var spawn_x: float = clampf(player_pos.x + randf_range(250.0, 390.0), 55.0, W - 55.0)
			var wave_hp: float = 28.0 + float(selected_planet) * 7.0
			enemies.append({"x":spawn_x,"y":460.0,"hp":wave_hp,"maxhp":wave_hp,"dir":-1.0,"alive":true,"boss":false,"flyer":false,"phase":randf()*4.0,"shot_timer":randf_range(1.5,2.5),"speed":randf_range(68.0,105.0)})
		_combat_banner("ALIEN WAVE! +" + str(wave_count) + " HOSTILES", Color("#ff6bda"))
		_spawn_burst(Vector2(clampf(player_pos.x + 280.0, 40.0, W-40.0), 455.0), Color("#c56bff"), 12, 150.0)
		wave_spawn_timer = randf_range(4.5, 7.0)
	# Aliens and the boss return fire, so combat requires movement and jumping.
	for e in enemies:
		if e["alive"] and not e.get("boss", false):
			e["shot_timer"] = float(e.get("shot_timer", randf_range(1.2, 2.4))) - delta
			if e["shot_timer"] <= 0.0 and abs(float(e["x"]) - player_pos.x) < 560.0:
				var edir: float = signf(player_pos.x - float(e["x"]))
				enemy_projectiles.append({"x":float(e["x"]),"y":float(e["y"])-20.0,"vx":edir*270.0,"vy":-35.0,"life":2.8,"damage":10.0+selected_planet*1.5,"kind":"alien"})
				e["shot_timer"] = randf_range(1.6, 2.6) - minf(0.45, selected_planet*0.035)
	if boss.get("alive", false):
		boss_fire_timer -= delta
		var new_phase := 1 if float(boss["hp"]) > float(boss["maxhp"])*0.55 else 2
		if new_phase != boss_phase:
			boss_phase = new_phase
			_combat_banner("BOSS PHASE " + str(boss_phase) + " — " + ("ARMOR BREAK" if boss_phase == 2 else "ENGAGED"), Color("#ff6bda"))
			screen_shake = maxf(screen_shake, 0.45)
			_spawn_burst(Vector2(float(boss["x"]), float(boss["y"])-30.0), Color("#ff43dc"), 26, 300.0)
		if boss_fire_timer <= 0.0 and abs(float(boss["x"])-player_pos.x) < 800.0:
			var dir_to_player: float = signf(player_pos.x - float(boss["x"]))
			var volley_count := 3 if boss_phase == 2 else 1
			for shot_i in range(volley_count):
				var vy := (float(shot_i)-float(volley_count-1)*0.5)*105.0
				enemy_projectiles.append({"x":float(boss["x"])-55.0,"y":float(boss["y"])-35.0,"vx":dir_to_player*(320.0+boss_phase*35.0),"vy":vy,"life":3.0,"damage":16.0+selected_planet*2.0,"kind":"boss"})
			boss_fire_timer = 1.55 if boss_phase == 2 else 2.4
	for ep in enemy_projectiles:
		ep["x"] += float(ep["vx"])*delta
		ep["y"] += float(ep["vy"])*delta
		ep["life"] -= delta
		var epr := Rect2(float(ep["x"])-9.0,float(ep["y"])-7.0,18.0,14.0)
		if epr.intersects(pr):
			_hurt(float(ep["damage"]))
			_spawn_burst(Vector2(float(ep["x"]),float(ep["y"])), Color("#ff386f") if ep["kind"] == "boss" else Color("#c46cff"), 9, 180.0)
			_spawn_text(Vector2(player_pos.x, player_pos.y-65.0), "-"+str(int(ep["damage"])), Color("#ff5a77"), 19)
			ep["life"] = -1.0
	enemy_projectiles = enemy_projectiles.filter(func(ep): return float(ep["life"]) > 0.0)

	for b in bullets:
		b["x"] += float(b["dir"]) * float(b.get("speed",720.0)) * delta
		b["life"] -= delta
		var br := Rect2(b["x"]-10, b["y"]-4, 20, 8)
		for e in enemies:
			if e["alive"] and br.intersects(Rect2(e["x"]-23,e["y"]-34,46,36)):
				e["hp"] -= b["damage"]
				b["life"] = -1
				_play_sfx("hit")
				_spawn_burst(Vector2(float(e["x"]),float(e["y"])-14.0), Color("#ff4b9a"), 7, 175.0)
				_spawn_text(Vector2(float(e["x"]),float(e["y"])-42.0), str(int(b["damage"])), Color("#9ef8ff"), 16)
				screen_shake = maxf(screen_shake, 0.08)
				hitstop = maxf(hitstop, 0.025)
				if e["hp"] <= 0:
					e["alive"] = false
					kills += 1
					total_kills += 1
					hero_kills[selected_hero] += 1
					combo_count += 1
					combo_timer = 3.0
					var bonus: int = 100 + maxi(0, combo_count - 1) * 25
					score += bonus
					coins += 5 + (2 if combo_count >= 3 else 0)
					_play_sfx("kill")
					_spawn_burst(Vector2(float(e["x"]),float(e["y"])-15.0), Color("#ff4cc8"), 30, 310.0)
					_spawn_text(Vector2(float(e["x"]),float(e["y"])-70.0), "ALIEN DOWN! +"+str(bonus), Color("#ffdf70"), 21)
					_combat_banner((str(combo_count)+"x KILL COMBO!" if combo_count >= 2 else "ALIEN ELIMINATED!")+"  +"+str(5 + (2 if combo_count >= 3 else 0))+" COINS", Color("#7affce"))
					screen_shake = maxf(screen_shake, 0.25 if combo_count < 3 else 0.4)
					screen_flash = maxf(screen_flash, 0.14)
					hitstop = maxf(hitstop, 0.065 if combo_count < 3 else 0.1)
				break
		if boss.get("alive",false) and br.intersects(Rect2(boss["x"]-65,boss["y"]-75,130,78)):
			boss["hp"] -= b["damage"]
			b["life"] = -1
			_spawn_burst(Vector2(float(boss["x"])+randf_range(-28.0,28.0),float(boss["y"])-35.0+randf_range(-20.0,20.0)), Color("#ff44df"), 12, 220.0)
			_spawn_text(Vector2(float(boss["x"]),float(boss["y"])-92.0), str(int(b["damage"])), Color("#ffe17b"), 18)
			screen_shake = maxf(screen_shake, 0.16)
			hitstop = maxf(hitstop, 0.045)
			if boss["hp"] <= 0:
				boss["alive"] = false
				score += 1000
				kills += 1
				total_kills += 1
				hero_kills[selected_hero] += 1
				coins += 50
				_play_sfx("boss")
				_spawn_burst(Vector2(float(boss["x"]),float(boss["y"])-35.0), Color("#ff4dd8"), 100, 520.0)
				_spawn_burst(Vector2(float(boss["x"]),float(boss["y"])-35.0), Color("#45eaff"), 65, 380.0)
				_spawn_text(Vector2(float(boss["x"])-70.0,float(boss["y"])-125.0), "OVERLORD DESTROYED! +1000", Color("#fff0a6"), 28)
				_combat_banner("BOSS DESTROYED!  +50 COINS  •  PLANET CLEARED", Color("#fff0a6"))
				screen_shake = 1.0
				screen_flash = 0.8
				hitstop = 0.22
				enemy_projectiles.clear()
				_save_game()
		if b["x"] < world_scroll-50 or b["x"] > player_pos.x+1000:
			b["life"] = -1
	bullets = bullets.filter(func(b): return b["life"] > 0)
	for c in pickups:
		if not c["taken"] and abs(c["x"]-player_pos.x)<28 and abs(c["y"]-player_pos.y)<50:
			c["taken"] = true
			coins += 1
			score += 10
			_play_sfx("coin")
			_spawn_burst(Vector2(float(c["x"]),float(c["y"])), Color("#ffd65a"), 10, 150.0)
			_spawn_text(Vector2(float(c["x"]),float(c["y"])-24.0), "+10", Color("#ffe37a"), 16)
	if player_pos.x > level_length - 120 and not boss.get("alive",false):
		score += 500
		unlocked_planets = maxi(unlocked_planets, mini(50, selected_planet + 2))
		_save_game()
		screen = Screen.WIN
	if player_hp <= 0:
		lives -= 1
		if lives <= 0:
			screen = Screen.GAME_OVER
			_save_game()
		else:
			player_hp = float(heroes[selected_hero]["hp"])
			player_pos = Vector2(max(40.0, player_pos.x-120), 500)
			player_vel = Vector2.ZERO
			invulnerable = 2.0
			_notify("LIFE LOST — " + str(lives) + " LIVES LEFT")

func _jump() -> void:
	if on_ground:
		player_vel.y = -560.0
		on_ground = false

func _play_sfx(sound_name: String) -> void:
	if sfx_players.has(sound_name):
		var player: AudioStreamPlayer = sfx_players[sound_name]
		player.stop()
		player.play()

func _select_weapon(index: int) -> void:
	weapon_type = clampi(index,0,3)
	_play_sfx("upgrade")
	_combat_banner(weapon_names[weapon_type] + " EQUIPPED", [Color("#48eaff"),Color("#9cecff"),Color("#d68bff"),Color("#ff8a4b")][weapon_type])

func _shoot() -> void:
	if shoot_cooldown <= 0.0:
		var damage: float = weapon_damage[weapon_type] + float(weapon_level-1)*6.0
		var speed: float = [820.0,1120.0,650.0,500.0][weapon_type]
		var life: float = [1.15,0.95,1.4,1.8][weapon_type]
		_play_sfx("laser" if weapon_type == 1 else ("kill" if weapon_type == 3 else "shot"))
		bullets.append({"x":player_pos.x + facing*30,"y":player_pos.y-23,"dir":facing,"life":life,"damage":damage,"speed":speed,"kind":weapon_type})
		if weapon_type == 2:
			bullets.append({"x":player_pos.x + facing*26,"y":player_pos.y-30,"dir":facing,"life":life,"damage":damage*0.55,"speed":speed,"kind":weapon_type})
		shoot_cooldown = maxf(0.10, weapon_cooldowns[weapon_type] - float(weapon_level-1)*0.025)

func _hurt(amount: float) -> void:
	if invulnerable <= 0:
		_play_sfx("hurt")
		player_hp -= amount
		if player_hp <= 0:
			player_hp = 0
		invulnerable = 0.65

func _upgrade_weapon() -> void:
	if weapon_level >= 5:
		_notify("WEAPON MAX LEVEL REACHED")
		return
	if coins < 10:
		_notify("NEED " + str(10 - coins) + " MORE COINS (COST: 10)")
		return
	coins -= 10
	weapon_level += 1
	_play_sfx("upgrade")
	_notify("WEAPON UPGRADED TO LV " + str(weapon_level) + "  •  COINS LEFT: " + str(coins))
	_save_game()

func _notify(msg: String) -> void:
	game_message = msg
	message_timer = 2.0

func _save_game() -> void:
	save_data = {"profile":profile_slot,"hero":selected_hero,"planet":selected_planet,"unlocked_planets":unlocked_planets,"coins":coins,"weapon":weapon_level,"score":score,"kills":kills,"hero_kills":hero_kills,"story_seen":story_seen}
	var f := FileAccess.open(SAVE_PREFIX + str(profile_slot + 1) + ".json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save_data))

func _load_save() -> bool:
	var profile_path := SAVE_PREFIX + str(profile_slot + 1) + ".json"
	if not FileAccess.file_exists(profile_path):
		selected_hero = 0
		selected_planet = 0
		planet_page = 0
		unlocked_planets = 1
		coins = 0
		weapon_level = 1
		score = 0
		kills = 0
		return false
	var f := FileAccess.open(profile_path, FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			save_data = parsed
			profile_slot = clampi(int(save_data.get("profile",profile_slot)),0,2)
			profile_name = "PLAYER " + str(profile_slot + 1)
			selected_hero = clampi(int(save_data.get("hero",0)),0,9)
			selected_planet = clampi(int(save_data.get("planet",0)),0,49)
			unlocked_planets = clampi(int(save_data.get("unlocked_planets",1)),1,50)
			planet_page = int(selected_planet / 10)
			coins = int(save_data.get("coins",0))
			weapon_level = clampi(int(save_data.get("weapon",1)),1,5)
			score = int(save_data.get("score",0))
			kills = int(save_data.get("kills",0))
			story_seen = bool(save_data.get("story_seen", false))
			var saved_ranks = save_data.get("hero_kills", [])
			if saved_ranks is Array:
				for rank_index in range(mini(10,saved_ranks.size())):
					hero_kills[rank_index] = int(saved_ranks[rank_index])
			return true
	return false

func _draw() -> void:
	if screen == Screen.GAME and screen_shake > 0.0:
		var shake_power := screen_shake * 10.0
		draw_set_transform(Vector2(randf_range(-shake_power,shake_power),randf_range(-shake_power,shake_power)),0.0,Vector2.ONE)
	_draw_background()
	match screen:
		Screen.MENU: _draw_menu()
		Screen.HOW_TO_PLAY: _draw_how_to_play()
		Screen.PROFILE: _draw_profile()
		Screen.HEROES: _draw_heroes()
		Screen.PLANETS: _draw_planets()
		Screen.STORY: _draw_story()
		Screen.GAME: _draw_game()
		Screen.GAME_OVER: _draw_end(false)
		Screen.WIN: _draw_end(true)
	if screen == Screen.GAME:
		_draw_combat_fx()
		if screen_flash > 0.0:
			draw_rect(Rect2(0,0,W,H),Color(0.55,0.88,1.0,clampf(screen_flash*0.28,0.0,0.22)))
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _spawn_burst(pos: Vector2, tint: Color, count: int, force: float) -> void:
	for i in range(count):
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(force*0.25, force)
		effects.append({"pos":pos,"vel":Vector2(cos(angle),sin(angle))*speed,"life":randf_range(0.22,0.62),"maxlife":0.62,"size":randf_range(2.0,6.0),"color":tint,"kind":"spark"})
	effects.append({"pos":pos,"vel":Vector2.ZERO,"life":0.24,"maxlife":0.24,"size":8.0,"color":tint,"kind":"ring"})

func _spawn_text(pos: Vector2, label: String, tint: Color, size: int) -> void:
	floating_texts.append({"pos":pos,"text":label,"color":tint,"life":0.9,"maxlife":0.9,"size":size})

func _combat_banner(label: String, tint: Color) -> void:
	game_message = label
	message_timer = 1.7

func _update_combat_fx(delta: float) -> void:
	for fx in effects:
		fx["pos"] = Vector2(fx["pos"]) + Vector2(fx["vel"])*delta
		fx["vel"] = Vector2(fx["vel"])*pow(0.05,delta)
		fx["life"] = float(fx["life"])-delta
	effects = effects.filter(func(fx): return float(fx["life"]) > 0.0)
	for ft in floating_texts:
		ft["pos"] = Vector2(ft["pos"])+Vector2(0,-38.0*delta)
		ft["life"] = float(ft["life"])-delta
	floating_texts = floating_texts.filter(func(ft): return float(ft["life"]) > 0.0)

func _draw_combat_fx() -> void:
	for fx in effects:
		var life_ratio := clampf(float(fx["life"])/float(fx["maxlife"]),0.0,1.0)
		var pos: Vector2 = fx["pos"]
		var col: Color = fx["color"]
		col.a = life_ratio
		if fx["kind"] == "ring":
			var radius := (1.0-life_ratio)*58.0+8.0
			draw_arc(pos,radius,0.0,TAU,32,col,3.0*life_ratio+0.5)
		else:
			draw_circle(pos,float(fx["size"])*life_ratio,col)
			draw_line(pos,pos-Vector2(fx["vel"])*0.035,col,1.5)
	for ft in floating_texts:
		var col: Color = ft["color"]
		col.a = clampf(float(ft["life"])/float(ft["maxlife"]),0.0,1.0)
		draw_string(ThemeDB.fallback_font,Vector2(ft["pos"]),str(ft["text"]),HORIZONTAL_ALIGNMENT_CENTER,360,int(ft["size"]),col)

func _draw_background() -> void:
	# Full-screen user-provided alien-planet background; gameplay platforms and hazards draw above it.
	if background_texture != null:
		draw_texture_rect(background_texture, Rect2(0, 0, W, H), false)
	else:
		draw_rect(Rect2(0, 0, W, H), Color("#061326"))
	# Slight tint keeps HUD text readable without hiding the artwork.
	draw_rect(Rect2(0, 0, W, H), Color(0.01, 0.025, 0.06, 0.12), true)

func _draw_title(text: String, y: float=52.0) -> void:
	draw_string(ThemeDB.fallback_font,Vector2(42,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,32,Color("#55e7ff"))

func _panel(r: Rect2, title: String) -> void:
	draw_rect(r,Color(0.015,0.045,0.09,0.96),true)
	draw_rect(r,Color("#1679a8"),false,2)
	draw_string(ThemeDB.fallback_font,Vector2(r.position.x+18,r.position.y+30),title,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("#b4f6ff"))

func _button(r: Rect2, label: String, active: bool=true) -> void:
	draw_rect(r,Color("#064b70") if active else Color("#172638"))
	draw_rect(r,Color("#36dcff") if active else Color("#526779"),false,2)
	var font_size := 22 if label.length() < 22 else 18
	var text_width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x + (r.size.x - text_width) * 0.5, r.position.y + r.size.y * 0.5 + 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE if active else Color("#8295a7"))

func _draw_menu() -> void:
	draw_string(ThemeDB.fallback_font,Vector2(54,115),"K20",HORIZONTAL_ALIGNMENT_LEFT,-1,84,Color("#49dfff"))
	draw_string(ThemeDB.fallback_font,Vector2(235,105),": ALIEN SURVIVAL",HORIZONTAL_ALIGNMENT_LEFT,-1,36,Color.WHITE)
	draw_string(ThemeDB.fallback_font,Vector2(58,151),"FIGHT  •  EXPLORE  •  SURVIVE",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("#7ecaff"))
	_button(Rect2(42,174,350,42),"PROFILE: "+profile_name+"  •  CLICK TO SWITCH",true)
	draw_string(ThemeDB.fallback_font,Vector2(58,230),"Saved progress is separate for each profile.",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#a7cce8"))
	_draw_player(Vector2(300,520),1,Color("#48dfff"),1.0)
	_draw_alien(Vector2(865,515),1.5)
	_draw_alien(Vector2(1015,525),0.9)
	_draw_alien(Vector2(1130,490),2.2)
	draw_string(ThemeDB.fallback_font,Vector2(490,330),"EARTH IS GONE. HUMANITY IS NEXT.",HORIZONTAL_ALIGNMENT_CENTER,600,27,Color("#f6fbff"))
	draw_string(ThemeDB.fallback_font,Vector2(490,360),"FIGHT  •  SURVIVE  •  UNLOCK 50 WORLDS",HORIZONTAL_ALIGNMENT_CENTER,600,19,Color("#a6c9e8"))
	_button(Rect2(470,390,340,54),"START MISSION  /  HOW TO PLAY")
	_button(Rect2(470,452,340,48),"STORY MODE")
	_button(Rect2(470,508,340,48),"PLAYER PROFILE / STATS")
	_button(Rect2(470,564,340,48),"LOAD SAVED PROFILE")
	draw_string(ThemeDB.fallback_font,Vector2(40,690),"K20: ALIEN SURVIVAL  |  GODOT 4 PROTOTYPE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#608eac"))

func _draw_how_to_play() -> void:
	_draw_title("HOW TO PLAY // FIELD GUIDE")
	_panel(Rect2(70,105,1140,490), "MISSION RULES & CONTROLS")
	draw_string(ThemeDB.fallback_font, Vector2(110,165), "OBJECTIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("#ffcf70"))
	_wrap_text("Defeat aliens and the Overlord, collect energy coins, avoid hazards, and clear planets to unlock the next world.", Vector2(110,193), 1030, 24, Color.WHITE, 18)
	draw_string(ThemeDB.fallback_font, Vector2(110,245), "PC CONTROLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#55e7ff"))
	_wrap_text("A / LEFT ARROW: move left     D / RIGHT ARROW: move right     SPACE / W / UP: jump", Vector2(110,273), 1030, 24, Color("#dcecff"), 17)
	_wrap_text("F / ENTER: fire     E: upgrade weapon (costs 10 coins)     1-4: change weapon     M: music", Vector2(110,297), 1030, 24, Color("#dcecff"), 17)
	_wrap_text("ESC: return to menu. Your hero has 3 lives; the red bar shows remaining health.", Vector2(110,321), 1030, 24, Color("#dcecff"), 17)
	draw_string(ThemeDB.fallback_font, Vector2(110,365), "MOBILE CONTROLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#55e7ff"))
	_wrap_text("Use LEFT / RIGHT to move, JUMP to cross hazards and platforms, and hold FIRE to shoot. Tap UPGRADE to spend 10 coins and improve your weapon.", Vector2(110,393), 1030, 24, Color("#dcecff"), 17)
	draw_string(ThemeDB.fallback_font, Vector2(110,450), "LOAD SAVED PROFILE // PLAYER 1, 2, 3", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#55e7ff"))
	_wrap_text("The menu's PROFILE button switches between 3 separate save slots. LOAD SAVED PROFILE loads progress from the selected slot, including hero, planet unlocks, coins and weapon level. Each player slot keeps its own progress; an unused slot starts fresh.", Vector2(110,477), 1030, 23, Color("#dcecff"), 16)
	draw_string(ThemeDB.fallback_font, Vector2(110,557), "TIP: Jump early, keep firing, and save progress by completing missions.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffdc7a"))
	_button(Rect2(40,620,180,60), "BACK")
	_button(Rect2(900,620,320,60), "CHOOSE HERO  ➜")

func _draw_profile() -> void:
	_draw_title("PLAYER PROFILE // SAVE SLOT " + str(profile_slot + 1))
	_panel(Rect2(100,110,1080,470), "SQUAD RECORD")
	_draw_player(Vector2(255,300), 1, heroes[selected_hero]["color"], 1.8)
	draw_string(ThemeDB.fallback_font, Vector2(390,185), profile_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(390,230), "SELECTED HERO: " + heroes[selected_hero]["name"] + " / " + heroes[selected_hero]["kind"], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, heroes[selected_hero]["color"])
	draw_string(ThemeDB.fallback_font, Vector2(390,280), "HERO HEALTH: " + str(heroes[selected_hero]["hp"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ff9caf"))
	draw_string(ThemeDB.fallback_font, Vector2(390,325), "CURRENT PLANET: " + str(selected_planet + 1) + " / " + planets[selected_planet]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#70eaff"))
	draw_string(ThemeDB.fallback_font, Vector2(390,370), "PLANETS UNLOCKED: " + str(unlocked_planets) + " / 50", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#75ffb9"))
	draw_string(ThemeDB.fallback_font, Vector2(390,415), "COINS: " + str(coins) + "     WEAPON LEVEL: " + str(weapon_level) + " / 5", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ffdc7a"))
	draw_string(ThemeDB.fallback_font, Vector2(390,460), "TOTAL KILLS: " + str(total_kills + kills) + "     HERO RANK: " + str(1 + int(hero_kills[selected_hero] / 5)), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	var slot_path := SAVE_PREFIX + str(profile_slot + 1) + ".json"
	var slot_status := "SAVED PROGRESS FOUND" if FileAccess.file_exists(slot_path) else "EMPTY SLOT - START A NEW MISSION"
	draw_string(ThemeDB.fallback_font, Vector2(390,510), slot_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#70ffb1") if FileAccess.file_exists(slot_path) else Color("#ffdc7a"))
	draw_string(ThemeDB.fallback_font, Vector2(390,540), "Each player slot stores progress separately.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#a7cce8"))
	_button(Rect2(40,630,180,56), "SWITCH SLOT")
	_button(Rect2(1000,630,220,56), "BACK TO MENU")

func _draw_heroes() -> void:
	_draw_title("SELECT YOUR HERO")
	draw_string(ThemeDB.fallback_font,Vector2(44,91),"Choose a specialist. Each hero has a different suit and health rating.",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#b4cce4"))
	for i in range(10):
		var x := 42.0 + float(i%5)*244.0
		var y := 120.0 + float(i/5)*220.0
		var selected := i == selected_hero
		draw_rect(Rect2(x,y,220,190),Color("#0b2440") if not selected else Color("#103b58"))
		draw_rect(Rect2(x,y,220,190),Color("#45eaff") if selected else Color("#315b7b"),false,3 if selected else 1)
		if i < hero_textures.size() and hero_textures[i] != null:
			draw_texture_rect(hero_textures[i], Rect2(x+7,y+7,100,145), false, Color.WHITE)
			draw_rect(Rect2(x+8,y+8,98,143), Color("#42dfff") if selected else Color("#4a7595"), false, 2.0)
		else:
			_draw_player(Vector2(x+55,y+80),1,heroes[i]["color"],0.8)
		draw_string(ThemeDB.fallback_font,Vector2(x+108,y+48),heroes[i]["name"],HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(x+108,y+72),heroes[i]["kind"],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#9fdcf2"))
		draw_string(ThemeDB.fallback_font,Vector2(x+108,y+96),"HP "+str(heroes[i]["hp"]),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#ffb9c6"))
		draw_string(ThemeDB.fallback_font,Vector2(x+108,y+119),"RANK "+str(1+int(hero_kills[i]/5)),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#ffdc7a"))
		draw_string(ThemeDB.fallback_font,Vector2(x+16,y+162),"SUIT PROFILE  "+str(i+1).pad_zeros(2),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#76dfff"))
		if selected:
			draw_string(ThemeDB.fallback_font,Vector2(x+155,y+28),"SELECTED",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#58ffb8"))
	_button(Rect2(1000,630,220,56),"CONTINUE  ➜")
	_button(Rect2(40,630,180,56),"BACK")

func _draw_planets() -> void:
	_draw_title("CHOOSE A PLANET  //  SECTOR " + str(planet_page + 1) + " / 5")
	draw_string(ThemeDB.fallback_font,Vector2(44,91),"50 worlds. Clear each mission to unlock the next planet.",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#b4cce4"))
	for i in range(10):
		var idx := planet_page * 10 + i
		var x := 36.0 + float(i%5)*244.0
		var y := 120.0 + float(i/5)*220.0
		var p: Dictionary = planets[idx]
		var col: Color = p["color"]
		var is_unlocked := idx < unlocked_planets
		draw_rect(Rect2(x,y,220,190),Color("#0b1b31") if is_unlocked else Color("#080e19"))
		draw_rect(Rect2(x,y,220,190),col if idx==selected_planet else (Color("#315b7b") if is_unlocked else Color("#29313c")),false,3 if idx==selected_planet else 1)
		if is_unlocked:
			if gameplay_art != null:
				var planet_src := Rect2(761.0 + float(idx % 10)*67.4, 52.0, 61.0, 72.0)
				draw_texture_rect_region(gameplay_art, Rect2(x+15,y+12,72,78), planet_src, Color.WHITE, false, true)
			else:
				draw_circle(Vector2(x+50,y+50),32,col.darkened(0.35))
				draw_circle(Vector2(x+45,y+45),25,col)
			draw_string(ThemeDB.fallback_font,Vector2(x+100,y+40),"WORLD "+str(idx+1),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#9eeaff"))
			draw_string(ThemeDB.fallback_font,Vector2(x+100,y+67),p["name"],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
			draw_string(ThemeDB.fallback_font,Vector2(x+14,y+137),p["difficulty"]+"  •  "+p["desc"],HORIZONTAL_ALIGNMENT_LEFT,-1,11,col.lightened(0.2))
			draw_string(ThemeDB.fallback_font,Vector2(x+14,y+169),"UNLOCKED",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#70ffb1"))
		else:
			draw_circle(Vector2(x+55,y+49),29,Color("#263243"))
			draw_arc(Vector2(x+55,y+45),13,PI,TAU,24,Color("#91a4ba"),5.0)
			draw_rect(Rect2(x+43,y+44,24,23),Color("#91a4ba"))
			draw_string(ThemeDB.fallback_font,Vector2(x+100,y+40),"WORLD "+str(idx+1),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#758396"))
			draw_string(ThemeDB.fallback_font,Vector2(x+100,y+67),"LOCKED",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#a5afbc"))
			draw_string(ThemeDB.fallback_font,Vector2(x+14,y+137),"CLEAR WORLD "+str(idx)+" TO UNLOCK",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#9aa7b7"))
	_button(Rect2(40,630,180,56),"BACK")
	_button(Rect2(260,630,180,56),"◀ PREVIOUS")
	_button(Rect2(470,630,180,56),"NEXT SECTOR ▶")
	_button(Rect2(1000,630,220,56),"STORY / PLAY  ➜")

func _draw_story() -> void:
	_draw_title("K20 // STORY TRANSMISSION")
	var heads := [
		"CHAPTER 01 — THE FALL",
		"CHAPTER 02 — THE LAST ARK",
        "CHAPTER 03 — TEN HOSTILE WORLDS"
	]
	var body := [
		"In 2197, the sky opened above Earth. The first alien wave broke every defence in hours. Cities went dark, oceans boiled, and the homeworld was lost.",
		"A small fleet escaped aboard the K20 Ark. You are one of its last defenders. The Ark is damaged, its power is fading, and millions of lives depend on your next mission.",
        "Ten planets guard the alien signal. Fight through hazards, collect energy coins, upgrade your weapons, and defeat the Overlord at Omega. If the signal survives, Earth was only the beginning."
	]
	_panel(Rect2(90,155,1100,390),"TRANSMISSION "+str(story_page+1)+" / 3")
	draw_string(ThemeDB.fallback_font,Vector2(130,230),heads[story_page],HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("#ffcf70"))
	_draw_player(Vector2(220,395),1,heroes[selected_hero]["color"],0.8)
	_wrap_text(body[story_page],Vector2(340,295),760,30,Color("#e1efff"),20)
	_button(Rect2(700,620,220,60),"SKIP STORY  ➜")
	_button(Rect2(950,620,270,60),"NEXT / START  ➜")
	draw_string(ThemeDB.fallback_font,Vector2(92,660),"Tip: Move with A/D, jump with SPACE, shoot with F, upgrade with E.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#83b4d5"))

func _draw_game() -> void:
	# Gameplay uses live game objects, not the static concept-art screenshot.
	# This makes every alien, projectile and boss correspond to its real hitbox.
	draw_rect(Rect2(0, 0, W, H), Color(planets[selected_planet]["color"], 0.10))
	draw_circle(Vector2(1040, 170), 142, Color(planets[selected_planet]["color"], 0.22))
	draw_circle(Vector2(1040, 170), 132, Color(planets[selected_planet]["color"], 0.12))
	# Sector-specific skyline silhouettes give each group of worlds a distinct look.
	var skyline_seed := selected_planet % 5
	for skyline_i in range(7):
		var sx := float(skyline_i) * 205.0 - 10.0
		var skyline_h := 55.0 + float((skyline_i * 31 + skyline_seed * 47) % 115)
		var skyline_color: Color = planets[selected_planet]["color"].darkened(0.68 + float(skyline_seed) * 0.035)
		draw_colored_polygon(PackedVector2Array([Vector2(sx,570), Vector2(sx+72,570-skyline_h), Vector2(sx+145,570)]), skyline_color)

	# Draw actual platforms and dangerous zones used by the physics/collision code.
	for platform in platforms:
		draw_rect(platform, Color("#263f55"))
		draw_rect(Rect2(platform.position.x, platform.position.y, platform.size.x, 5), Color("#38cfff"))
		draw_rect(Rect2(platform.position.x, platform.position.y + 5, platform.size.x, maxf(0.0, platform.size.y - 5)), Color("#102338"))
	for hz in hazards:
		var hazard_rect := Rect2(float(hz["x"]), float(hz["y"]), float(hz["w"]), float(hz["h"]))
		if hz["type"] == "LAVA":
			draw_rect(hazard_rect, Color("#ff4d27"))
			draw_line(hazard_rect.position, hazard_rect.position + Vector2(hazard_rect.size.x, 0), Color("#ffb34d"), 4)
		elif hz["type"] == "POISON":
			draw_rect(hazard_rect, Color("#3dff8b"))
			draw_rect(Rect2(hazard_rect.position, Vector2(hazard_rect.size.x, 4)), Color("#c0ffd8"))
		elif hz["type"] == "ELECTRIC":
			draw_rect(hazard_rect, Color("#554bff"))
			for wire_x in range(0, int(hazard_rect.size.x), 18):
				draw_line(hazard_rect.position + Vector2(wire_x, 0), hazard_rect.position + Vector2(wire_x + 9, -10), Color("#a9b8ff"), 3.0)
		elif hz["type"] == "VOID":
			draw_rect(hazard_rect, Color("#5a1a83"))
			draw_line(hazard_rect.position, hazard_rect.position + Vector2(hazard_rect.size.x, 0), Color("#df76ff"), 4.0)
		else:
			var spike_count := maxi(3, int(hazard_rect.size.x / 15.0))
			for si in range(spike_count):
				var sx := hazard_rect.position.x + float(si) * hazard_rect.size.x / float(spike_count)
				var sw := hazard_rect.size.x / float(spike_count)
				draw_colored_polygon(PackedVector2Array([Vector2(sx, hazard_rect.position.y + hazard_rect.size.y), Vector2(sx + sw * 0.5, hazard_rect.position.y - 10), Vector2(sx + sw, hazard_rect.position.y + hazard_rect.size.y)]), Color("#eaf7ff"))

	# Dynamic status panel.
	draw_rect(Rect2(18,124,305,86), Color(0.005,0.025,0.055,0.96))
	draw_rect(Rect2(18,124,305,86), Color("#24bfff"), false, 2)
	draw_string(ThemeDB.fallback_font, Vector2(32,145), profile_name + "  •  " + heroes[selected_hero]["name"] + "  RANK " + str(1 + int(hero_kills[selected_hero] / 5)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(32,165), "PLANET " + str(selected_planet+1) + ": " + planets[selected_planet]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#78eaff"))
	draw_rect(Rect2(32,174,180,10), Color("#351e34"))
	draw_rect(Rect2(32,174,180*clampf(player_hp/float(heroes[selected_hero]["hp"]),0.0,1.0),10), Color("#ff405d"))
	draw_string(ThemeDB.fallback_font, Vector2(218,184), "HP " + str(int(player_hp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(32,202), "SCORE " + str(score) + "   COINS " + str(coins) + "   LIVES " + str(lives), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ffdc7a"))
	draw_string(ThemeDB.fallback_font, Vector2(32,221), "WEAPON " + weapon_names[weapon_type] + "  LV " + str(weapon_level) + "  [1-4 SWITCH]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8eeaff"))

	# Draw every living enemy at the same coordinates used by its hitbox.
	for e in enemies:
		if e["alive"]:
			var enemy_pos := Vector2(float(e["x"]), float(e["y"]) - 7.0)
			var alien_scale := 0.82 if e.get("flyer", false) else 0.72
			_draw_alien(enemy_pos, alien_scale)
			var bar_x := float(e["x"]) - 25.0
			var bar_y := float(e["y"]) - 48.0
			draw_rect(Rect2(bar_x, bar_y, 50, 6), Color("#341426"))
			draw_rect(Rect2(bar_x, bar_y, 50 * clampf(float(e["hp"]) / float(e["maxhp"]), 0.0, 1.0), 6), Color("#ff315d"))
	if boss.get("alive", false):
		# The Overlord is a real drawable enemy, not a creature baked into a background image.
		_draw_alien(Vector2(float(boss["x"]), float(boss["y"]) - 35.0), 2.0)
		draw_rect(Rect2(930, 224, 280, 12), Color("#42172b"))
		draw_rect(Rect2(930, 224, 280 * clampf(float(boss["hp"]) / float(boss["maxhp"]), 0.0, 1.0), 12), Color("#ff315d"))

	# Player and shots are interactive; obstacles are collision-tested by the level simulation.
	var px: float = player_pos.x
	if invulnerable <= 0 or int(Time.get_ticks_msec()/100)%2==0:
		_draw_player(Vector2(px,player_pos.y-38),facing,heroes[selected_hero]["color"],1.0)
	# Health bar directly above the selected hero; lives are shown in the HUD as 3 chances.
	var hero_bar_x := player_pos.x - 28.0
	var hero_bar_y := player_pos.y - 82.0
	draw_rect(Rect2(hero_bar_x, hero_bar_y, 56.0, 7.0), Color("#42172b"))
	draw_rect(Rect2(hero_bar_x, hero_bar_y, 56.0 * clampf(player_hp / float(heroes[selected_hero]["hp"]), 0.0, 1.0), 7.0), Color("#ff315d"))
	for bullet in bullets:
		var bpos := Vector2(float(bullet["x"]),float(bullet["y"]))
		var bt := int(bullet.get("kind",0))
		var tint: Color = [Color("#45efff"),Color("#d9fbff"),Color("#c56bff"),Color("#ff7a3d")][bt]
		var length: float = [25.0,38.0,19.0,15.0][bt]
		draw_line(bpos-Vector2(float(bullet["dir"])*length,0),bpos+Vector2(float(bullet["dir"])*10.0,0),Color(tint,0.45),12.0 if bt==3 else 7.0)
		draw_line(bpos-Vector2(float(bullet["dir"])*length*0.6,0),bpos+Vector2(float(bullet["dir"])*8.0,0),tint,6.0 if bt==3 else 3.0)
		draw_circle(bpos,7.0 if bt==3 else (5.0 if bt==2 else 3.0),Color.WHITE)
	for ep in enemy_projectiles:
		var epos := Vector2(float(ep["x"]),float(ep["y"]))
		var ec := Color("#ff3f6b") if ep["kind"] == "boss" else Color("#c56bff")
		draw_line(epos-Vector2(float(ep["vx"])*0.035,float(ep["vy"])*0.035),epos,ec,7 if ep["kind"] == "boss" else 4)
		draw_circle(epos,6 if ep["kind"] == "boss" else 4,Color.WHITE)

	if combo_count >= 2 and combo_timer > 0.0:
		draw_rect(Rect2(430,60,420,42),Color(0.015,0.02,0.08,0.88))
		draw_string(ThemeDB.fallback_font,Vector2(450,88),str(combo_count)+"x KILL COMBO!",HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color("#ffdf70"))
	if boss.get("alive",false):
		draw_string(ThemeDB.fallback_font,Vector2(1000,245),"OVERLORD • PHASE "+str(boss_phase),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#ff8de8"))

	# Clear, functional objective/control overlay.
	draw_rect(Rect2(1080,126,185,62), Color(0.005,0.025,0.055,0.96))
	draw_rect(Rect2(1080,126,185,62), Color("#24bfff"), false, 2)
	draw_string(ThemeDB.fallback_font,Vector2(1092,148),"OBJECTIVE",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
	draw_string(ThemeDB.fallback_font,Vector2(1092,169),"ELIMINATE ALIENS",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#ffce48"))
	draw_string(ThemeDB.fallback_font,Vector2(1100,208),"MUSIC: ON" if music_enabled else "MUSIC: OFF",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#8eeaff"))
	draw_string(ThemeDB.fallback_font,Vector2(22,705),"MOVE A/D  •  JUMP SPACE  •  SHOOT F  •  WEAPONS 1-4  •  UPGRADE E  •  PAUSE ESC",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#d7edff"))
	# Touchscreen controls for Android.
	_draw_touch_button(Rect2(35,565,95,110), "◀", touch_left)
	_draw_touch_button(Rect2(135,565,95,110), "▶", touch_right)
	_draw_touch_button(Rect2(250,555,130,125), "JUMP", false)
	_draw_touch_button(Rect2(1090,555,150,125), "FIRE", touch_shoot)
	_draw_touch_button(Rect2(955,465,120,75), "UPGRADE 10", false)
	if message_timer > 0:
		var banner_alpha := clampf(message_timer,0.0,1.0)
		draw_rect(Rect2(300,104,680,46),Color(0.01,0.04,0.08,0.96*banner_alpha))
		draw_rect(Rect2(300,104,680,46),Color("#45eaff",0.9*banner_alpha),false,2)
		draw_string(ThemeDB.fallback_font,Vector2(320,134),game_message,HORIZONTAL_ALIGNMENT_CENTER,640,19,Color(0.48,1.0,0.82,banner_alpha))

func _draw_touch_button(r: Rect2, label: String, active: bool) -> void:
	var fill_color := Color(0.05,0.55,0.78,0.78) if active else Color(0.02,0.08,0.16,0.72)
	draw_rect(r, fill_color, true)
	draw_rect(r, Color("#72eaff"), false, 3.0)
	var font_size := 16 if label == "UPGRADE 10" else (24 if label in ["JUMP", "FIRE"] else 30)
	var text_width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x + (r.size.x - text_width) * 0.5, r.position.y + r.size.y * 0.5 + font_size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _draw_end(won: bool) -> void:
	draw_rect(Rect2(0,0,W,H),Color(0.01,0.025,0.06,0.88))
	_panel(Rect2(290,180,700,360),"K20 // MISSION REPORT")
	if won:
		draw_string(ThemeDB.fallback_font,Vector2(470,280),"PLANET CLEARED!",HORIZONTAL_ALIGNMENT_LEFT,-1,42,Color("#61ffbb"))
		draw_string(ThemeDB.fallback_font,Vector2(420,330),"Boss defeated. The Ark survives another day.",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(420,375),"Score: "+str(score)+"   Kills: "+str(kills)+"   Coins: "+str(coins),HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#ffdc7a"))
		_button(Rect2(490,475,300,60),"NEXT PLANET")
	else:
		draw_string(ThemeDB.fallback_font,Vector2(490,280),"MISSION FAILED",HORIZONTAL_ALIGNMENT_LEFT,-1,42,Color("#ff5876"))
		draw_string(ThemeDB.fallback_font,Vector2(420,330),"Your squad needs you. Retry the mission.",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(420,375),"Score: "+str(score)+"   Kills: "+str(kills),HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#ffdc7a"))
		_button(Rect2(490,475,300,60),"RETRY MISSION")

func _draw_player(pos: Vector2, dir: int, tint: Color, scale: float) -> void:
	# Render the exact character selected in the HEROES screen.
	if selected_hero >= 0 and selected_hero < hero_textures.size() and hero_textures[selected_hero] != null:
		var hero_texture: Texture2D = hero_textures[selected_hero]
		var sprite_w := 76.0 * scale
		var sprite_h := 100.0 * scale
		var sprite_rect := Rect2(pos.x - sprite_w * 0.5, pos.y - 56.0 * scale, sprite_w, sprite_h)
		draw_texture_rect(hero_texture, sprite_rect, false, Color.WHITE)
		return
	var s := scale
	# Fallback vector soldier if hero art is unavailable.
	draw_line(pos+Vector2(-9*s,20*s),pos+Vector2(-16*s,37*s),Color("#142b43"),8*s)
	draw_line(pos+Vector2(8*s,20*s),pos+Vector2(14*s,37*s),Color("#142b43"),8*s)
	draw_line(pos+Vector2(-16*s,37*s),pos+Vector2(-24*s,38*s),tint,5*s)
	draw_line(pos+Vector2(14*s,37*s),pos+Vector2(23*s,38*s),tint,5*s)
	draw_colored_polygon(PackedVector2Array([pos+Vector2(-15*s,-5*s),pos+Vector2(12*s,-5*s),pos+Vector2(17*s,22*s),pos+Vector2(-12*s,22*s)]),Color("#1c3f5b"))
	draw_rect(Rect2(pos.x-13*s,pos.y-2*s,25*s,5*s),tint)
	draw_circle(pos+Vector2(0,-18*s),12*s,Color("#172d43"))
	draw_circle(pos+Vector2(0,-19*s),9*s,Color("#b8d9ec"))
	draw_rect(Rect2(pos.x-9*s,pos.y-21*s,18*s,5*s),tint)
	draw_line(pos+Vector2(7*s,2*s),pos+Vector2(20*s,-1*s),Color("#6f91a9"),6*s)
	draw_line(pos+Vector2(20*s,-1*s),pos+Vector2(35*s,-1*s),tint,5*s)
	draw_line(pos+Vector2(35*s,-1*s),pos+Vector2(40*s,-1*s),Color.WHITE,2*s)
	draw_circle(pos+Vector2(-4*s,-18*s),2*s,Color("#061326"))

func _draw_alien(pos: Vector2, scale: float) -> void:
	# Use the supplied creature references for live enemies and the boss.
	# Their position follows the actual enemy hitboxes.
	if scale >= 1.5 and boss_alien_art != null:
		var boss_size := Vector2(330.0, 300.0) * (scale / 2.0)
		draw_texture_rect(boss_alien_art, Rect2(pos - boss_size * 0.5, boss_size), false)
		return
	if mini_alien_art != null:
		var mini_size := Vector2(62.0, 72.0) * (scale / 0.72)
		draw_texture_rect(mini_alien_art, Rect2(pos - mini_size * 0.5, mini_size), false)
		return
	var s := scale
	draw_colored_polygon(PackedVector2Array([pos+Vector2(-25*s,12*s),pos+Vector2(-18*s,-14*s),pos+Vector2(-3*s,-26*s),pos+Vector2(20*s,-18*s),pos+Vector2(30*s,5*s),pos+Vector2(18*s,22*s),pos+Vector2(-17*s,22*s)]),Color("#492c78"))
	draw_colored_polygon(PackedVector2Array([pos+Vector2(-17*s,-9*s),pos+Vector2(-3*s,-23*s),pos+Vector2(16*s,-15*s),pos+Vector2(22*s,2*s),pos+Vector2(10*s,12*s),pos+Vector2(-15*s,8*s)]),Color("#8e49cf"))
	draw_circle(pos+Vector2(8*s,-9*s),4*s,Color("#ff3e8a"))
	draw_circle(pos+Vector2(8*s,-9*s),1.5*s,Color.WHITE)
	draw_line(pos+Vector2(-10*s,15*s),pos+Vector2(-22*s,29*s),Color("#9a57d5"),5*s)
	draw_line(pos+Vector2(14*s,15*s),pos+Vector2(26*s,29*s),Color("#9a57d5"),5*s)
	draw_line(pos+Vector2(-10*s,-18*s),pos+Vector2(-21*s,-31*s),Color("#b97cff"),3*s)
	draw_line(pos+Vector2(14*s,-17*s),pos+Vector2(24*s,-29*s),Color("#b97cff"),3*s)

func _wrap_text(text: String, pos: Vector2, max_width: float, line_h: float, color: Color, font_size: int) -> void:
	var words := text.split(" ")
	var line := ""
	var y := pos.y
	for word in words:
		var test := line + (" " if line != "" else "") + word
		if ThemeDB.fallback_font.get_string_size(test,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > max_width:
			draw_string(ThemeDB.fallback_font,Vector2(pos.x,y),line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
			y += line_h
			line = word
		else:
			line = test
	if line != "":
		draw_string(ThemeDB.fallback_font,Vector2(pos.x,y),line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
