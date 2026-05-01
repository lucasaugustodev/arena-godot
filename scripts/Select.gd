extends Control

# Character select scene.
# Click two bichos then "FIGHT!" to start the battle.

signal fight_started(left_id: String, right_id: String)

var selected_left: String = ""
var selected_right: String = ""
var hovered_id: String = ""
var time: float = 0.0

const TILE_W := 200
const TILE_H := 130
const COLS := 4
const GAP := 14
const TOP := 130

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(dt):
	time += dt
	queue_redraw()

func _gui_input(event):
	if event is InputEventMouseMotion:
		hovered_id = _bicho_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Fight button check
		var fight_rect = _fight_button_rect()
		if selected_left != "" and selected_right != "" and fight_rect.has_point(event.position):
			emit_signal("fight_started", selected_left, selected_right)
			return
		var id = _bicho_at(event.position)
		if id != "":
			if selected_left == "":
				selected_left = id
			elif selected_right == "" and id != selected_left:
				selected_right = id
			else:
				selected_left = id
				selected_right = ""

func _bicho_at(pos: Vector2) -> String:
	for i in range(Bichos.ROSTER.size()):
		var r = _tile_rect(i)
		if r.has_point(pos):
			return Bichos.ROSTER[i].id
	return ""

func _tile_rect(i: int) -> Rect2:
	var c = i % COLS
	var r = i / COLS
	var total_w = COLS * TILE_W + (COLS - 1) * GAP
	var x0 = (size.x - total_w) / 2.0
	var x = x0 + c * (TILE_W + GAP)
	var y = TOP + r * (TILE_H + GAP)
	return Rect2(x, y, TILE_W, TILE_H)

func _fight_button_rect() -> Rect2:
	return Rect2(size.x / 2 - 130, size.y - 70, 260, 50)

func _draw():
	# Background gradient
	for i in range(40):
		var ratio = float(i) / 40.0
		var c = Color("#0a0a18").lerp(Color("#1a0a30"), ratio)
		draw_rect(Rect2(0, i * size.y / 40.0, size.x, size.y / 40.0 + 1), c)
	# Subtle red glow top-left + purple bottom-right (like CSS radial gradients)
	for i in range(30):
		var t = float(i) / 30.0
		var radius = 200 + i * 12
		draw_circle(Vector2(size.x * 0.3, size.y * 0.3), radius, Color(0.5, 0.13, 0.13, 0.02 * (1.0 - t)))
		draw_circle(Vector2(size.x * 0.7, size.y * 0.8), radius, Color(0.27, 0.13, 0.5, 0.02 * (1.0 - t)))

	_draw_title()
	_draw_grid()
	_draw_vs_panel()
	if selected_left != "" and selected_right != "":
		_draw_fight_button()
	else:
		_draw_hint()

func _draw_title():
	var center = Vector2(size.x / 2, 60)
	var rect = Rect2(center.x - 240, center.y - 32, 480, 64)
	draw_rect(rect, Color("#7a1024"))
	draw_rect(rect, Color("#ffd23d"), false, 3)
	var title = "⚔  ARENA DO BICHO  ⚔"
	var font = ThemeDB.fallback_font
	var fs = 32
	var tsize = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var pos = Vector2(center.x - tsize.x / 2, center.y + fs / 4.0)
	draw_string(font, pos + Vector2(2, 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.5))
	draw_string(font, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#ffd23d"))

func _draw_grid():
	for i in range(Bichos.ROSTER.size()):
		var b = Bichos.ROSTER[i]
		var r = _tile_rect(i)
		var is_left  = b.id == selected_left
		var is_right = b.id == selected_right
		var hovered  = b.id == hovered_id

		# Background
		draw_rect(r, b.color)
		# Inner darker
		var inner = Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4))
		draw_rect(inner, b.color.darkened(0.35))

		# Border based on selection
		var border_color = Color(1, 1, 1, 0.2)
		if is_left:        border_color = Color("#ff5050")
		elif is_right:     border_color = Color("#50a8ff")
		elif hovered:      border_color = Color("#ffd23d")
		draw_rect(r, border_color, false, 3)

		# Sprite
		var tex = load("res://assets/characters/" + b.folder + "/idle.png")
		if tex:
			var sprite_size = Vector2(72, 72)
			var sprite_pos = r.position + Vector2(14, 16)
			draw_texture_rect(tex, Rect2(sprite_pos, sprite_size), false)

		# Name
		var font = ThemeDB.fallback_font
		var name_pos = Vector2(r.position.x + r.size.x - 12, r.position.y + 22)
		var name_size = font.get_string_size(b.name, HORIZONTAL_ALIGNMENT_RIGHT, -1, 18)
		draw_string(font, name_pos - Vector2(name_size.x, 0), b.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

		# Style
		var style_pos = Vector2(r.position.x + r.size.x - 12, r.position.y + 44)
		var style_size = font.get_string_size(b.style, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12)
		draw_string(font, style_pos - Vector2(style_size.x, 0), b.style, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.75))

		# Stats row
		var sy = r.position.y + r.size.y - 16
		draw_string(font, Vector2(r.position.x + 12, sy), "❤ %d" % b.hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ff7077"))
		draw_string(font, Vector2(r.position.x + 60, sy), "⚔ %d-%d" % [b.atk_min, b.atk_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffc450"))
		draw_string(font, Vector2(r.position.x + 132, sy), "⚡ %d" % b.speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#7adfff"))

		# Selection badge
		if is_left:  _draw_badge(r.position + Vector2(r.size.x - 26, 8), "P1", Color("#ff5050"))
		if is_right: _draw_badge(r.position + Vector2(r.size.x - 26, 8), "P2", Color("#50a8ff"))

func _draw_badge(pos: Vector2, text: String, color: Color):
	draw_circle(pos + Vector2(8, 8), 12, color)
	var font = ThemeDB.fallback_font
	var tsize = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	draw_string(font, pos + Vector2(8 - tsize.x / 2, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

func _draw_vs_panel():
	# P1 box
	_draw_slot(Vector2(50, size.y - 130), Vector2(150, 80), "P1", Color("#ff5050"), selected_left)
	_draw_slot(Vector2(size.x - 200, size.y - 130), Vector2(150, 80), "P2", Color("#50a8ff"), selected_right)
	# VS
	var font = ThemeDB.fallback_font
	var vs_pos = Vector2(size.x / 2, size.y - 90)
	var ts = font.get_string_size("VS", HORIZONTAL_ALIGNMENT_CENTER, -1, 38)
	draw_string(font, vs_pos - Vector2(ts.x / 2, 0), "VS", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color("#ffd23d"))

func _draw_slot(pos: Vector2, sz: Vector2, label: String, color: Color, bicho_id: String):
	var r = Rect2(pos, sz)
	draw_rect(r, Color(0, 0, 0, 0.55))
	draw_rect(r, color, false, 2)
	var font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(10, 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	if bicho_id != "":
		var b = Bichos.get_by_id(bicho_id)
		var tex = load("res://assets/characters/" + b.folder + "/idle.png")
		if tex:
			draw_texture_rect(tex, Rect2(pos + Vector2(10, 24), Vector2(48, 48)), false)
		var name_size = font.get_string_size(b.name, HORIZONTAL_ALIGNMENT_RIGHT, -1, 18)
		draw_string(font, pos + Vector2(sz.x - 10 - name_size.x, 44), b.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	else:
		draw_string(font, pos + Vector2(sz.x / 2 - 50, 50), "escolha um bicho", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.5))

func _draw_fight_button():
	var r = _fight_button_rect()
	var pulse = (sin(time * 4.0) + 1.0) / 2.0
	# Glow
	for i in range(3):
		var glow_r = Rect2(r.position - Vector2(8 - i * 2, 8 - i * 2), r.size + Vector2(16 - i * 4, 16 - i * 4))
		draw_rect(glow_r, Color(1.0, 0.4, 0.2, 0.15 * pulse))
	# Button
	draw_rect(r, Color("#ff7733"))
	draw_rect(r, Color("#ffd23d"), false, 3)
	var font = ThemeDB.fallback_font
	var label = "⚔  COMEÇAR LUTA  ⚔"
	var ts = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
	draw_string(font, r.position + Vector2((r.size.x - ts.x) / 2, r.size.y / 2 + 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

func _draw_hint():
	var font = ThemeDB.fallback_font
	var hint = "Selecione dois bichos para começar"
	var ts = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	draw_string(font, Vector2((size.x - ts.x) / 2, size.y - 40), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.5))
