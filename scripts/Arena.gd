extends Control

# Battle arena — plays back a pre-simulated battle with animated bichos.
# Bichos are static PNG (256x256-ish) animated via state phases that drive
# position offsets, scale pulses, rotation (KO fall), and shake.

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
const SPRITE_SIZE := 180.0   # final draw size for the round animal sprite

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
		"home_pos": pos,
		"facing": facing,
		"hp": bicho.hp,
		"max_hp": bicho.hp,
		"state": "idle",
		"shake": 0.0,
		"tint_age": 999.0,
		"float_texts": [],
		"texture": load("res://assets/characters/" + bicho.file),
		"bob_phase": randf() * TAU,        # idle bob
		"attack_phase": 0.0,               # 0..1 progress, 1=just started
		"attack_kind": "quick",
		"hit_phase": 0.0,
		"ko_phase": 0.0,
		"victory_phase": 0.0,
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
	if rig.shake > 0: rig.shake = max(0, rig.shake - dt * 20)
	if rig.tint_age < 1.0: rig.tint_age += dt
	if rig.attack_phase > 0:
		rig.attack_phase = max(0.0, rig.attack_phase - dt * 2.2)
		if rig.attack_phase <= 0.0 and rig.state in ["attacking_quick", "attacking_heavy"]:
			rig.state = "idle"
	if rig.hit_phase > 0:
		rig.hit_phase = max(0.0, rig.hit_phase - dt * 4.0)
	if rig.state == "ko" and rig.ko_phase < 1.0:
		rig.ko_phase = min(1.0, rig.ko_phase + dt * 2.5)
	if rig.state == "victory":
		rig.victory_phase = fposmod(rig.victory_phase + dt * 4.0, TAU)

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
	elif ev.type == "hit":
		var rig = left_rig if ev.defender == "left" else right_rig
		rig.hp = ev.defender_hp
		rig.shake = 12.0 if ev.crit else 8.0
		rig.tint_age = 0.0
		rig.hit_phase = 1.0
		rig.float_texts.append({
			"text": "-%d%s" % [ev.dmg, "!" if ev.crit else ""],
			"crit": ev.crit, "age": 0.0, "lifetime": 1.1,
			"pos": rig.pos + Vector2(0, -200),
		})
		flash_alpha = 0.7 if ev.crit else 0.35
		camera_shake = 8.0 if ev.crit else 4.0
		var midpoint = (left_rig.pos + right_rig.pos) / 2.0
		_spawn_hit_spark(midpoint + Vector2(0, -100), ev.crit)
	elif ev.type == "ko":
		var rig = left_rig if ev.loser == "left" else right_rig
		rig.state = "ko"
	elif ev.type == "victory":
		var rig = left_rig if ev.winner == "left" else right_rig
		rig.state = "victory"
		flash_alpha = 1.0
		_spawn_confetti(80)

func _spawn_hit_spark(pos: Vector2, crit: bool):
	var n = 18 if crit else 10
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
	# Sky gradient (top down to floor)
	for i in range(40):
		var y = i * FLOOR_Y / 40.0
		var c = Color("#3a2018").lerp(Color("#7a3818"), float(i) / 40.0)
		draw_rect(Rect2(0 + shake_off.x, y + shake_off.y, size.x, FLOOR_Y / 40.0 + 1), c)
	# Ground
	draw_rect(Rect2(0 + shake_off.x, FLOOR_Y + shake_off.y, size.x, size.y - FLOOR_Y), Color("#1a0a06"))
	# Sand stripes for texture
	for i in range(8):
		var y = FLOOR_Y + 8 + i * 15
		draw_rect(Rect2(0 + shake_off.x, y + shake_off.y, size.x, 2), Color(0.13, 0.07, 0.04))

func _draw_rig(rig: Dictionary, shake_off: Vector2):
	if not rig:
		return

	# Compute draw transform
	var bob_y = sin(rig.bob_phase) * 6.0 if rig.state == "idle" else 0.0
	var attack_offset = Vector2.ZERO
	var attack_scale = 1.0
	var attack_rot = 0.0
	if rig.attack_phase > 0:
		# attack_phase: 1=start, 0.5=peak (hit), 0=back
		# Use ease-in-out: lunge forward at peak
		var t = rig.attack_phase
		var ease_t = 1.0 - abs(t - 0.5) * 2.0   # 0 at 1.0, 1.0 at 0.5, 0 at 0
		attack_offset.x = ease_t * 80.0 * rig.facing
		attack_scale = 1.0 + ease_t * 0.15
		attack_rot = ease_t * 0.15 * rig.facing
		if rig.attack_kind == "heavy":
			attack_offset.x *= 1.3
			attack_rot *= 1.5

	var hit_offset_x = (randf() - 0.5) * rig.shake * 1.5
	var hit_offset_y = sin(rig.hit_phase * 12.0) * rig.hit_phase * 6.0

	var ko_rot = rig.ko_phase * (PI / 2.0) * rig.facing
	var ko_offset_y = rig.ko_phase * 30.0

	var victory_bounce = 0.0
	if rig.state == "victory":
		victory_bounce = abs(sin(rig.victory_phase)) * -25.0

	# Final draw position (sprite center)
	var center = rig.pos + shake_off + attack_offset + Vector2(hit_offset_x, bob_y + hit_offset_y + ko_offset_y + victory_bounce - SPRITE_SIZE / 2.0)

	# Floor shadow (squashed when in air)
	var shadow_y = rig.pos.y + shake_off.y + 8
	var shadow_w = 60.0
	if rig.state == "victory":
		shadow_w *= 1.0 - abs(sin(rig.victory_phase)) * 0.3
	draw_circle(Vector2(rig.pos.x + shake_off.x, shadow_y), shadow_w, Color(0, 0, 0, 0.4))

	# Sprite: rotated/scaled via canvas transform
	if rig.texture:
		var tex_size = Vector2(SPRITE_SIZE, SPRITE_SIZE) * attack_scale
		var rot = ko_rot + attack_rot
		var flip_x = -1 if rig.facing == -1 else 1
		# Build transform around sprite center
		var transform = Transform2D().rotated(rot)
		transform.origin = center
		draw_set_transform_matrix(transform)
		var rect = Rect2(-tex_size / 2.0, tex_size)
		if flip_x == -1:
			rect = Rect2(tex_size.x / 2.0, -tex_size.y / 2.0, -tex_size.x, tex_size.y)
		draw_texture_rect(rig.texture, rect, false)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	# Hit tint flash
	if rig.tint_age < 0.3:
		var alpha = 0.45 * (1.0 - rig.tint_age / 0.3)
		var rect = Rect2(center - Vector2(SPRITE_SIZE / 2.0, SPRITE_SIZE / 2.0), Vector2(SPRITE_SIZE, SPRITE_SIZE))
		draw_rect(rect, Color(1, 0.3, 0.3, alpha))

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
	var tex = load("res://assets/characters/" + winner.file)
	if tex:
		var sz = 220
		draw_texture_rect(tex, Rect2(Vector2(cx - sz / 2.0, cy - 80), Vector2(sz, sz)), false)
	var name_label = winner.name.to_upper()
	var t2 = font.get_string_size(name_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 56)
	draw_string(font, Vector2(cx - t2.x / 2, cy + 170), name_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color("#ffd23d"))
	var hint = "Clique para nova batalha"
	var t3 = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(font, Vector2(cx - t3.x / 2, cy + 220), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
