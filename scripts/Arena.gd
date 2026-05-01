extends Control

# Battle arena — pose-based animation (texture swap per state) + tweens.

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

const FLOOR_Y := 480.0
const SPRITE_SCALE := 3.5

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
	var folder = "res://assets/characters/" + bicho.folder + "/"
	return {
		"bicho": bicho,
		"pos": pos,
		"home_x": pos.x,
		"facing": facing,
		"hp": bicho.hp,
		"max_hp": bicho.hp,
		"state": "idle",
		"shake": 0.0,
		"tint_age": 999.0,
		"float_texts": [],
		"poses": {
			"idle":         load(folder + "idle.png"),
			"walk":         load(folder + "walk.png"),
			"attack_quick": load(folder + "attack_quick.png"),
			"attack_heavy": load(folder + "attack_heavy.png"),
			"hit":          load(folder + "hit.png"),
			"ko":           load(folder + "ko.png"),
			"victory":      load(folder + "victory.png"),
		},
		"bob_phase": randf() * TAU,
		"state_age": 0.0,
		"attack_phase": 0.0,
		"attack_kind": "quick",
		"attack_lunge_x": 0.0,
	}

func _process(dt):
	if not script_data:
		return
	time += dt

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
	rig.bob_phase += dt * 3.0
	rig.state_age += dt
	if rig.shake > 0: rig.shake = max(0, rig.shake - dt * 20)
	if rig.tint_age < 1.0: rig.tint_age += dt

	if rig.attack_phase > 0:
		rig.attack_phase = max(0.0, rig.attack_phase - dt * 2.5)
		# Lunge curve: forward fast, hold briefly at peak, recover
		var t = 1.0 - rig.attack_phase
		var lunge = 0.0
		if t < 0.3:        lunge = (t / 0.3) * 90.0      # wind-up forward
		elif t < 0.55:     lunge = 90.0                  # peak
		else:              lunge = 90.0 * (1.0 - (t - 0.55) / 0.45)
		rig.attack_lunge_x = lunge * rig.facing
		if rig.attack_phase <= 0.0 and rig.state in ["attacking_quick", "attacking_heavy"]:
			rig.state = "idle"
			rig.state_age = 0.0
			rig.attack_lunge_x = 0.0
	# Auto-recover from hit after a short stun
	if rig.state == "hit" and rig.state_age > 0.45:
		rig.state = "idle"
		rig.state_age = 0.0

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
		rig.attack_kind = ev.kind
		rig.attack_phase = 1.0
		rig.state_age = 0.0
	elif ev.type == "hit":
		var rig = left_rig if ev.defender == "left" else right_rig
		rig.hp = ev.defender_hp
		rig.shake = 14.0 if ev.crit else 8.0
		rig.tint_age = 0.0
		rig.state = "hit"
		rig.state_age = 0.0
		rig.float_texts.append({
			"text": "-%d%s" % [ev.dmg, "!" if ev.crit else ""],
			"crit": ev.crit, "age": 0.0, "lifetime": 1.1,
			"pos": rig.pos + Vector2(0, -200),
		})
		flash_alpha = 0.7 if ev.crit else 0.35
		camera_shake = 10.0 if ev.crit else 5.0
		var midpoint = (left_rig.pos + right_rig.pos) / 2.0
		_spawn_hit_spark(midpoint + Vector2(0, -100), ev.crit)
	elif ev.type == "ko":
		var rig = left_rig if ev.loser == "left" else right_rig
		rig.state = "ko"
		rig.state_age = 0.0
	elif ev.type == "victory":
		var rig = left_rig if ev.winner == "left" else right_rig
		rig.state = "victory"
		rig.state_age = 0.0
		flash_alpha = 1.0
		_spawn_confetti(80)

func _spawn_hit_spark(pos: Vector2, crit: bool):
	var n = 20 if crit else 12
	for i in range(n):
		var angle = randf() * TAU
		var sp = randf_range(120, 320)
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle) * sp, sin(angle) * sp - 80),
			"age": 0.0, "lifetime": randf_range(0.5, 0.9),
			"size": 8 if crit else 5,
			"color": Color("#ffd23d") if crit else Color.WHITE,
		})

func _spawn_confetti(n: int):
	for i in range(n):
		var angle = randf() * TAU
		var sp = randf_range(100, 320)
		particles.append({
			"pos": Vector2(size.x / 2, 280),
			"vel": Vector2(cos(angle) * sp, sin(angle) * sp - 100),
			"age": 0.0, "lifetime": randf_range(1.5, 2.3),
			"size": 6,
			"color": Color.from_hsv(randf(), 0.9, 1.0),
		})

func _input(event):
	if end_shown and event is InputEventMouseButton and event.pressed:
		emit_signal("battle_finished")

func _draw():
	var shake_off = Vector2((randf() - 0.5) * camera_shake, (randf() - 0.5) * camera_shake)
	_draw_arena_bg(shake_off)
	_draw_rig(left_rig,  shake_off)
	_draw_rig(right_rig, shake_off)
	for p in particles:
		var a = 1.0 - p.age / p.lifetime
		var c = p.color
		c.a = a
		draw_rect(Rect2(p.pos + shake_off - Vector2(p.size, p.size) / 2.0, Vector2(p.size, p.size)), c, true)
	if flash_alpha > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash_alpha * 0.5))
	_draw_hp_bars()
	if end_shown: _draw_winner()

func _draw_arena_bg(shake_off: Vector2):
	# Stadium gradient sky
	for i in range(40):
		var y = i * FLOOR_Y / 40.0
		var c = Color("#1a0a2e").lerp(Color("#7a3818"), float(i) / 40.0)
		draw_rect(Rect2(0 + shake_off.x, y + shake_off.y, size.x, FLOOR_Y / 40.0 + 1), c)
	# Crowd silhouettes (rows of dots)
	for row in range(3):
		var y = 200.0 + row * 30
		for i in range(int(size.x / 14) + 1):
			var x = (i + row * 0.5) * 14
			var bob = sin(time * 1.5 + x * 0.05 + row) * 2.0
			draw_circle(Vector2(x + shake_off.x, y + bob + shake_off.y), 4.0 + (i % 3) * 0.5, Color(0.05, 0.04, 0.07))
	# Ground
	draw_rect(Rect2(0 + shake_off.x, FLOOR_Y + shake_off.y, size.x, size.y - FLOOR_Y), Color("#1a0a06"))
	# Ground stripes
	for i in range(8):
		var y = FLOOR_Y + 8 + i * 12
		draw_rect(Rect2(0 + shake_off.x, y + shake_off.y, size.x, 2), Color(0.13, 0.07, 0.04))

func _draw_rig(rig: Dictionary, shake_off: Vector2):
	if not rig:
		return
	var tex = rig.poses.get(rig.state, rig.poses.idle)
	if not tex: tex = rig.poses.idle

	# Compute position
	var bob_y = sin(rig.bob_phase) * 5.0 if rig.state == "idle" else 0.0
	var hit_offset_x = 0.0
	if rig.state == "hit":
		# Quick recoil + shake
		var k = clamp(1.0 - rig.state_age / 0.45, 0.0, 1.0)
		hit_offset_x = -rig.facing * 30.0 * k + sin(rig.state_age * 60.0) * 6.0 * k

	# Victory bounce
	var victory_bounce = 0.0
	if rig.state == "victory":
		victory_bounce = abs(sin(rig.state_age * 4.0)) * -25.0

	var tex_size = tex.get_size() * SPRITE_SCALE
	var center_x = rig.pos.x + shake_off.x + rig.attack_lunge_x + hit_offset_x
	var bottom_y = rig.pos.y + shake_off.y + bob_y + victory_bounce

	# Floor shadow
	draw_circle(Vector2(rig.pos.x + shake_off.x, rig.pos.y + shake_off.y + 6), 50, Color(0, 0, 0, 0.4))

	# Sprite (flipped if facing left)
	var dst = Rect2(center_x - tex_size.x / 2.0, bottom_y - tex_size.y, tex_size.x, tex_size.y)
	if rig.facing == -1:
		dst = Rect2(center_x + tex_size.x / 2.0, bottom_y - tex_size.y, -tex_size.x, tex_size.y)
	# Hit tint via modulate-like effect: layer red over sprite
	draw_texture_rect(tex, dst, false)
	if rig.tint_age < 0.3:
		var alpha = 0.4 * (1.0 - rig.tint_age / 0.3)
		# Tint by drawing a translucent red sprite on top via blend trick
		var rect_above = Rect2(center_x - tex_size.x / 2.0, bottom_y - tex_size.y, tex_size.x, tex_size.y)
		draw_rect(rect_above, Color(1, 0.3, 0.3, alpha))

	# Floating damage numbers
	var font = ThemeDB.fallback_font
	for ft in rig.float_texts:
		var a = 1.0 - ft.age / ft.lifetime
		var fs = 32 if ft.crit else 26
		var color = Color("#ffd23d") if ft.crit else Color.WHITE
		color.a = a
		var ts = font.get_string_size(ft.text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var p = ft.pos + shake_off + Vector2(-ts.x / 2.0, 0)
		draw_string(font, p + Vector2(2, 2), ft.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, a * 0.6))
		draw_string(font, p, ft.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

func _draw_hp_bars():
	_draw_hp_bar(left_rig,  Vector2(40, 20), false)
	_draw_hp_bar(right_rig, Vector2(size.x - 360, 20), true)

func _draw_hp_bar(rig: Dictionary, pos: Vector2, align_right: bool):
	if not rig:
		return
	var W = 320
	var H = 28
	draw_rect(Rect2(pos - Vector2(2, 2), Vector2(W + 4, H + 4)), Color(0, 0, 0, 0.6))
	var ratio = float(rig.hp) / float(rig.max_hp)
	var fill_w = max(0, int(W * ratio))
	var color = Color("#22b755") if ratio > 0.5 else (Color("#c47410") if ratio > 0.25 else Color("#a01020"))
	var fx = pos.x + W - fill_w if align_right else pos.x
	draw_rect(Rect2(Vector2(fx, pos.y), Vector2(fill_w, H)), color)
	var font = ThemeDB.fallback_font
	var name_text = "%s  %s" % [rig.bicho.emoji, rig.bicho.name]
	var ts = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	var nx = pos.x + W - ts.x if align_right else pos.x
	draw_string(font, Vector2(nx, pos.y + H + 18), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	var hp_text = "%d / %d" % [rig.hp, rig.max_hp]
	var ths = font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(font, Vector2(pos.x + (W - ths.x) / 2.0, pos.y + 19), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func _draw_winner():
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var winner = left_bicho if script_data.winner == "left" else right_bicho
	var cx = size.x / 2
	var cy = size.y / 2 - 20
	var font = ThemeDB.fallback_font
	var t1 = font.get_string_size("VITÓRIA", HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
	draw_string(font, Vector2(cx - t1.x / 2, cy - 100), "VITÓRIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#fff5b8"))
	var tex = load("res://assets/characters/" + winner.folder + "/victory.png")
	if tex:
		var ts = tex.get_size() * 5.0
		draw_texture_rect(tex, Rect2(Vector2(cx - ts.x / 2.0, cy - ts.y / 2.0), ts), false)
	var name_label = winner.name.to_upper()
	var t2 = font.get_string_size(name_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 50)
	draw_string(font, Vector2(cx - t2.x / 2, cy + 200), name_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 50, Color("#ffd23d"))
	var hint = "Clique para nova batalha"
	var t3 = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(font, Vector2(cx - t3.x / 2, cy + 250), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
