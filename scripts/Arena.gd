extends Control

# Battle arena scene — plays back a pre-simulated battle.

signal battle_finished

var script_data: Dictionary = {}
var time: float = 0.0
var event_idx: int = 0
var end_shown: bool = false

var left_bicho: Dictionary = {}
var right_bicho: Dictionary = {}
var left_rig: Dictionary = {}
var right_rig: Dictionary = {}

var camera_shake: float = 0.0
var flash_alpha: float = 0.0
var particles: Array = []

const FLOOR_Y := 410.0
const SPRITE_SCALE := 4.0
const SPRITE_SIZE := 24  # Kenney pixel-platformer characters are 24x24

func start_battle(left_id: String, right_id: String):
	left_bicho  = Bichos.get_by_id(left_id)
	right_bicho = Bichos.get_by_id(right_id)
	left_rig  = _make_rig(left_bicho,  Vector2(280, FLOOR_Y), 1)
	right_rig = _make_rig(right_bicho, Vector2(680, FLOOR_Y), -1)
	script_data = Battle.simulate(left_bicho, right_bicho)
	event_idx = 0
	time = 0.0
	end_shown = false

func _make_rig(bicho: Dictionary, pos: Vector2, facing: int) -> Dictionary:
	return {
		"bicho": bicho,
		"pos": pos,
		"target_pos": pos,
		"facing": facing,
		"hp": bicho.hp,
		"max_hp": bicho.hp,
		"state": "idle",
		"shake": 0.0,
		"tint_age": 999.0,
		"float_texts": [],
		"texture": load("res://assets/characters/" + bicho.tile),
		"bob": 0.0,
		"attack_anim": 0.0,  # 0..1 progress through current attack
	}

func _process(dt):
	if not script_data:
		return
	time += dt

	# Apply scripted events whose time arrived
	while event_idx < script_data.events.size() and script_data.events[event_idx].t <= time:
		_apply_event(script_data.events[event_idx])
		event_idx += 1

	_update_rig(left_rig,  dt)
	_update_rig(right_rig, dt)
	_update_particles(dt)
	if camera_shake > 0: camera_shake = max(0, camera_shake - dt * 30)
	if flash_alpha > 0:  flash_alpha  = max(0, flash_alpha - dt * 3)

	if event_idx >= script_data.events.size() and time > script_data.duration and not end_shown:
		end_shown = true

	queue_redraw()

func _update_rig(rig: Dictionary, dt: float):
	rig.pos = rig.pos.lerp(rig.target_pos, min(1.0, dt * 6.0))
	rig.bob += dt
	if rig.shake > 0:    rig.shake    = max(0, rig.shake - dt * 24)
	if rig.tint_age < 1.0: rig.tint_age += dt
	if rig.attack_anim > 0:
		rig.attack_anim = max(0.0, rig.attack_anim - dt * 2.5)
		if rig.attack_anim <= 0.0 and rig.state in ["attacking_quick", "attacking_heavy"]:
			rig.state = "idle"
			rig.target_pos.x = 280 if rig.facing == 1 else 680
	for ft in rig.float_texts:
		ft.age += dt
		ft.pos.y -= 30 * dt
	rig.float_texts = rig.float_texts.filter(func(ft): return ft.age < ft.lifetime)

func _update_particles(dt: float):
	for p in particles:
		p.age += dt
		p.pos += p.vel * dt
		p.vel.y += 380 * dt
	particles = particles.filter(func(p): return p.age < p.lifetime)

func _apply_event(ev: Dictionary):
	if ev.type == "attack":
		var rig = left_rig if ev.attacker == "left" else right_rig
		rig.state = "attacking_heavy" if ev.kind == "heavy" else "attacking_quick"
		rig.attack_anim = 1.0
		rig.target_pos.x = rig.pos.x + (60.0 if rig.facing == 1 else -60.0)
	elif ev.type == "hit":
		var rig = left_rig if ev.defender == "left" else right_rig
		rig.hp = ev.defender_hp
		rig.shake = 8.0 if ev.crit else 5.0
		rig.tint_age = 0.0
		rig.float_texts.append({
			"text": "-%d%s" % [ev.dmg, "!" if ev.crit else ""],
			"crit": ev.crit, "age": 0.0, "lifetime": 1.1,
			"pos": rig.pos + Vector2(0, -120),
		})
		flash_alpha = 0.7 if ev.crit else 0.35
		camera_shake = 8.0 if ev.crit else 4.0
		_spawn_hit_spark(_midpoint(left_rig.pos, right_rig.pos) + Vector2(0, -50), ev.crit)
	elif ev.type == "ko":
		var rig = left_rig if ev.loser == "left" else right_rig
		rig.state = "ko"
	elif ev.type == "victory":
		flash_alpha = 1.0
		_spawn_confetti(80)

func _midpoint(a: Vector2, b: Vector2) -> Vector2:
	return (a + b) / 2.0

func _spawn_hit_spark(pos: Vector2, crit: bool):
	var n = 14 if crit else 8
	for i in range(n):
		var angle = randf() * TAU
		var sp = randf_range(80, 280)
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle) * sp, sin(angle) * sp - 60),
			"age": 0.0, "lifetime": randf_range(0.5, 0.9),
			"size": 6 if crit else 4,
			"color": Color("#ffd23d") if crit else Color.WHITE,
		})

func _spawn_confetti(n: int):
	for i in range(n):
		var angle = randf() * TAU
		var sp = randf_range(80, 300)
		particles.append({
			"pos": Vector2(size.x / 2, 280),
			"vel": Vector2(cos(angle) * sp, sin(angle) * sp - 100),
			"age": 0.0, "lifetime": randf_range(1.5, 2.3),
			"size": 5,
			"color": Color.from_hsv(randf(), 0.9, 1.0),
		})

func _input(event):
	if end_shown and event is InputEventMouseButton and event.pressed:
		emit_signal("battle_finished")

func _draw():
	var shake_off = Vector2((randf() - 0.5) * camera_shake, (randf() - 0.5) * camera_shake)
	# Background
	_draw_arena_bg(shake_off)
	# Fighters
	_draw_rig(left_rig,  shake_off)
	_draw_rig(right_rig, shake_off)
	# Particles
	for p in particles:
		var a = 1.0 - p.age / p.lifetime
		var c = p.color
		c.a = a
		draw_rect(Rect2(p.pos + shake_off - Vector2(p.size, p.size) / 2.0, Vector2(p.size, p.size)), c, true)
	# Flash
	if flash_alpha > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash_alpha * 0.5))
	# HUD
	_draw_hp_bars()
	# End overlay
	if end_shown:
		_draw_winner()

func _draw_arena_bg(shake_off: Vector2):
	# Sky gradient (top half)
	for i in range(20):
		var y = i * size.y / 40.0
		var c = Color("#3a2018").lerp(Color("#7a3818"), float(i) / 20.0)
		draw_rect(Rect2(0 + shake_off.x, y + shake_off.y, size.x, size.y / 40.0 + 1), c)
	# Ground
	draw_rect(Rect2(0 + shake_off.x, FLOOR_Y + shake_off.y, size.x, size.y - FLOOR_Y), Color("#1a0a06"))
	# Tile floor pattern (using kenney brick tile if available)
	var tile_brick = load("res://assets/tiles/tile_0001.png")
	if tile_brick:
		var ts := 32
		for i in range(int(size.x / ts) + 1):
			draw_texture_rect(tile_brick, Rect2(i * ts + shake_off.x, FLOOR_Y + shake_off.y, ts, ts), false)

func _draw_rig(rig: Dictionary, shake_off: Vector2):
	if not rig:
		return
	var sz = SPRITE_SIZE * SPRITE_SCALE
	var bob = sin(rig.bob * 3.0) * 2.0 if rig.state == "idle" else 0.0
	# Lunge offset for attacks (uses target_pos, smoothed)
	var draw_pos = rig.pos + shake_off + Vector2((randf() - 0.5) * rig.shake, bob - sz)
	var rect = Rect2(draw_pos.x - sz / 2.0, draw_pos.y, sz, sz)

	# Floor shadow
	draw_circle(rig.pos + shake_off + Vector2(0, 6), 38, Color(0, 0, 0, 0.4))

	# Sprite (flipped for facing -1)
	if rig.texture:
		var src = Rect2(Vector2.ZERO, Vector2(SPRITE_SIZE, SPRITE_SIZE))
		var dst = rect
		if rig.facing == -1:
			dst = Rect2(rect.position.x + rect.size.x, rect.position.y, -rect.size.x, rect.size.y)
		draw_texture_rect_region(rig.texture, dst, src, Color.WHITE, false)
	else:
		draw_rect(rect, rig.bicho.color)

	# Hit tint
	if rig.tint_age < 0.3:
		draw_rect(rect, Color(1, 0.3, 0.3, 0.4 * (1.0 - rig.tint_age / 0.3)))

	# KO rotation effect (visual: tint dark gray)
	if rig.state == "ko":
		draw_rect(rect, Color(0, 0, 0, 0.45))

	# Floating damage numbers
	for ft in rig.float_texts:
		var a = 1.0 - ft.age / ft.lifetime
		var fs = 28 if ft.crit else 22
		var color = Color("#ffd23d") if ft.crit else Color.WHITE
		color.a = a
		var font = ThemeDB.fallback_font
		var ts = font.get_string_size(ft.text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, ft.pos + shake_off + Vector2(-ts.x / 2.0 + 1, 1), ft.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, a * 0.6))
		draw_string(font, ft.pos + shake_off + Vector2(-ts.x / 2.0, 0), ft.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

func _draw_hp_bars():
	_draw_hp_bar(left_rig,  Vector2(40, 20), false)
	_draw_hp_bar(right_rig, Vector2(size.x - 360, 20), true)

func _draw_hp_bar(rig: Dictionary, pos: Vector2, align_right: bool):
	if not rig:
		return
	var W = 320
	var H = 28
	# Background
	draw_rect(Rect2(pos - Vector2(2, 2), Vector2(W + 4, H + 4)), Color(0, 0, 0, 0.6))
	var ratio = float(rig.hp) / float(rig.max_hp)
	var fill_w = max(0, int(W * ratio))
	var color = Color("#22b755") if ratio > 0.5 else (Color("#c47410") if ratio > 0.25 else Color("#a01020"))
	var fx = pos.x + W - fill_w if align_right else pos.x
	draw_rect(Rect2(Vector2(fx, pos.y), Vector2(fill_w, H)), color)
	# Name
	var font = ThemeDB.fallback_font
	var name_text = "%s  %s" % [rig.bicho.emoji, rig.bicho.name]
	var ts = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	var nx = pos.x + W - ts.x if align_right else pos.x
	draw_string(font, Vector2(nx, pos.y + H + 18), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	# HP text
	var hp_text = "%d / %d" % [rig.hp, rig.max_hp]
	var ths = font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(font, Vector2(pos.x + (W - ths.x) / 2.0, pos.y + 19), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func _draw_winner():
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var winner = left_bicho if script_data.winner == "left" else right_bicho
	var cx = size.x / 2
	var cy = size.y / 2 - 20
	var font = ThemeDB.fallback_font

	var t1 = font.get_string_size("VITÓRIA", HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	draw_string(font, Vector2(cx - t1.x / 2, cy - 60), "VITÓRIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#fff5b8"))

	var tex = load("res://assets/characters/" + winner.tile)
	if tex:
		var sz = 192
		draw_texture_rect(tex, Rect2(Vector2(cx - sz / 2.0, cy - 70), Vector2(sz, sz)), false)

	var name_label = winner.name.to_upper()
	var t2 = font.get_string_size(name_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 56)
	draw_string(font, Vector2(cx - t2.x / 2, cy + 130), name_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color("#ffd23d"))

	var hint = "Clique para nova batalha"
	var t3 = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(font, Vector2(cx - t3.x / 2, cy + 180), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
