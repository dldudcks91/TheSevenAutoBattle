class_name RunProgress
extends RefCounted

# 라운드 진행, 적 라운드 정의(rounds.csv), 라운드 보상.
# Economy/RosterStore에 대한 의존은 메서드 인자로 주입한다(DI).

var current_round: int = 0
var _round_defs: Array = []     # Array of Array[StringName] — enemy IDs per wave
var _round_tactics: Array = []  # Array of StringName — tactic_key per wave

func load_rounds() -> void:
	var rows := CsvLoader.load_table("res://src/data/rounds.csv")
	_round_defs.clear()
	_round_tactics.clear()
	for row in rows:
		_round_tactics.append(StringName(row.get("tactic_key", "").strip_edges()))
		var ekeys: Array = []
		for key in row.keys():
			var s := String(key)
			if s.begins_with("e") and s.substr(1).is_valid_int():
				ekeys.append(s)
		ekeys.sort_custom(func(a, b): return int(a.substr(1)) < int(b.substr(1)))
		var enemies: Array = []
		for key in ekeys:
			var val: String = row[key].strip_edges()
			if val != "":
				enemies.append(StringName(val))
		_round_defs.append(enemies)

func reset() -> void:
	current_round = 0

func total_rounds() -> int:
	return _round_defs.size()

func is_last_round() -> bool:
	return current_round >= total_rounds() - 1

func current_tactic_key() -> StringName:
	if current_round >= _round_tactics.size():
		return &""
	return _round_tactics[current_round]

func current_enemy_lineup() -> Array:
	if current_round >= _round_defs.size():
		return []
	var ids: Array = _round_defs[current_round]
	var lineup: Array = []
	for id in ids:
		lineup.append(UnitDB.get_by_id(id))
	return lineup

func current_round_reward(economy: Economy) -> int:
	return economy.REWARD_PER_ROUND + current_round * economy.REWARD_GROWTH_PER_ROUND

func grant_round_reward(economy: Economy) -> void:
	economy.gold += current_round_reward(economy)

func advance_round() -> void:
	current_round += 1
