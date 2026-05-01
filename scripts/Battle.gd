class_name Battle extends RefCounted

# Pre-simulates a fight between two bichos, returns event timeline for playback.

const ROUND_GAP = 1.4
const ATTACK_TIME = 0.6

static func simulate(left: Dictionary, right: Dictionary) -> Dictionary:
	var a := { "stats": left,  "hp": left.hp,  "side": "left" }
	var b := { "stats": right, "hp": right.hp, "side": "right" }
	var order: Array = [a, b] if a.stats.speed >= b.stats.speed else [b, a]

	var events: Array = []
	var t := 0.4
	var round_num := 1
	while a.hp > 0 and b.hp > 0 and round_num < 30:
		for attacker in order:
			if a.hp <= 0 or b.hp <= 0:
				break
			var defender = b if attacker == a else a
			var dmg_info = _roll_damage(attacker.stats)
			defender.hp = max(0, defender.hp - dmg_info.dmg)
			events.append({
				"t": t, "type": "attack",
				"attacker": attacker.side, "defender": defender.side,
				"kind": "heavy" if dmg_info.crit else ("quick" if randf() < 0.5 else "heavy")
			})
			events.append({
				"t": t + ATTACK_TIME * 0.55, "type": "hit",
				"defender": defender.side,
				"dmg": dmg_info.dmg, "crit": dmg_info.crit,
				"defender_hp": defender.hp,
			})
			t += ATTACK_TIME + ROUND_GAP * 0.6
			if defender.hp <= 0:
				events.append({ "t": t, "type": "ko", "loser": defender.side })
				t += 1.2
				events.append({ "t": t, "type": "victory", "winner": attacker.side })
				t += 2.0
				break
		round_num += 1

	var winner = "left" if a.hp > 0 else "right"
	return {
		"events": events,
		"duration": t,
		"winner": winner,
		"left_final_hp": a.hp,
		"right_final_hp": b.hp,
	}

static func _roll_damage(stats: Dictionary) -> Dictionary:
	var base = randf_range(stats.atk_min, stats.atk_max)
	var crit = randf() < stats.crit
	return { "dmg": int(round(base * (1.6 if crit else 1.0))), "crit": crit }
