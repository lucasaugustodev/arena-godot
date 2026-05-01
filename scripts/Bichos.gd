class_name Bichos extends RefCounted

# Roster of "bichos" using Kenney animal-pack-remastered sprites.
# All animals come from PNG/Round/ — round vector art, transparent background.

const ROSTER = [
	{
		"id": "aguia", "name": "Águia", "emoji": "🦅",
		"file": "owl.png",
		"weapon": "Cimitarra", "style": "Velocista",
		"hp": 100, "atk_min": 12, "atk_max": 20, "speed": 16, "crit": 0.18,
		"color": Color("#c4923a")
	},
	{
		"id": "jacare", "name": "Jacaré", "emoji": "🐊",
		"file": "crocodile.png",
		"weapon": "Mandíbula", "style": "Tanque",
		"hp": 140, "atk_min": 14, "atk_max": 22, "speed": 8, "crit": 0.10,
		"color": Color("#4a7a3a")
	},
	{
		"id": "leao", "name": "Leão", "emoji": "🦁",
		"file": "gorilla.png",
		"weapon": "Garras", "style": "Equilibrado",
		"hp": 120, "atk_min": 14, "atk_max": 22, "speed": 13, "crit": 0.18,
		"color": Color("#d4a020")
	},
	{
		"id": "tigre", "name": "Tigre", "emoji": "🐅",
		"file": "panda.png",
		"weapon": "Patada", "style": "Assassino",
		"hp": 100, "atk_min": 13, "atk_max": 21, "speed": 18, "crit": 0.25,
		"color": Color("#e87030")
	},
	{
		"id": "urso", "name": "Urso", "emoji": "🐻",
		"file": "bear.png",
		"weapon": "Mordida", "style": "Berserker",
		"hp": 160, "atk_min": 18, "atk_max": 28, "speed": 6, "crit": 0.12,
		"color": Color("#7a4a20")
	},
	{
		"id": "cobra", "name": "Cobra", "emoji": "🐍",
		"file": "snake.png",
		"weapon": "Veneno", "style": "Mago",
		"hp": 90, "atk_min": 12, "atk_max": 24, "speed": 17, "crit": 0.20,
		"color": Color("#6a9a30")
	},
	{
		"id": "touro", "name": "Touro", "emoji": "🐂",
		"file": "buffalo.png",
		"weapon": "Chifrada", "style": "Investida",
		"hp": 145, "atk_min": 17, "atk_max": 25, "speed": 9, "crit": 0.10,
		"color": Color("#7a3818")
	},
	{
		"id": "macaco", "name": "Macaco", "emoji": "🐒",
		"file": "monkey.png",
		"weapon": "Acrobacia", "style": "Marcial",
		"hp": 100, "atk_min": 11, "atk_max": 19, "speed": 17, "crit": 0.22,
		"color": Color("#a47a40")
	},
]

static func get_by_id(id: String) -> Dictionary:
	for b in ROSTER:
		if b.id == id:
			return b
	return {}
