class_name Bichos extends RefCounted

# 5 fighters using Kenney platformer-characters with pose-based animation.
# Each has a folder with: idle.png, walk.png, attack_quick.png, attack_heavy.png,
# hit.png, ko.png, victory.png

const ROSTER = [
	{
		"id": "adventurer", "name": "O Aventureiro", "emoji": "⚔️",
		"folder": "adventurer",
		"weapon": "Espada", "style": "Equilibrado",
		"hp": 110, "atk_min": 13, "atk_max": 21, "speed": 13, "crit": 0.18,
		"color": Color("#7c3aed"),
	},
	{
		"id": "female", "name": "A Heroína", "emoji": "🗡️",
		"folder": "female",
		"weapon": "Lâmina", "style": "Velocista",
		"hp": 100, "atk_min": 12, "atk_max": 22, "speed": 17, "crit": 0.22,
		"color": Color("#e63946"),
	},
	{
		"id": "player", "name": "O Atleta", "emoji": "💪",
		"folder": "player",
		"weapon": "Punhos", "style": "Marcial",
		"hp": 105, "atk_min": 12, "atk_max": 19, "speed": 15, "crit": 0.20,
		"color": Color("#ffd23d"),
	},
	{
		"id": "soldier", "name": "O Soldado", "emoji": "🪖",
		"folder": "soldier",
		"weapon": "Rifle", "style": "Tanque",
		"hp": 140, "atk_min": 16, "atk_max": 24, "speed": 9, "crit": 0.12,
		"color": Color("#22b755"),
	},
	{
		"id": "zombie", "name": "O Zumbi", "emoji": "🧟",
		"folder": "zombie",
		"weapon": "Mordida", "style": "Berserker",
		"hp": 150, "atk_min": 15, "atk_max": 25, "speed": 7, "crit": 0.10,
		"color": Color("#06b6d4"),
	},
]

static func get_by_id(id: String) -> Dictionary:
	for b in ROSTER:
		if b.id == id:
			return b
	return {}
