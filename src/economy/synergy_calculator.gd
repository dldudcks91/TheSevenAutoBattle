class_name SynergyCalculator
extends RefCounted

# 그리드 위 유닛 종류 → 직업·종족 시너지 카운트 + 발동 단계.
# "종류 단위 1 카운트" — 같은 종류가 여러 셀·여러 명이어도 1만 잡힌다 (SYNERGY_DESIGN.md §6).

# RunState.grid_cells (Array[Array[Dictionary{slot:RosterSlot,...}]]) → 종류별 UnitData 1회씩.
static func unique_types_from_grid(grid_cells: Array) -> Array[UnitData]:
	var seen: Dictionary = {}
	var out: Array[UnitData] = []
	for cell in grid_cells:
		for entry in (cell as Array):
			var slot: RosterSlot = (entry as Dictionary).get("slot")
			if slot == null:
				continue
			var ud: UnitData = slot.unit_data
			if ud == null:
				continue
			if seen.has(ud.id):
				continue
			seen[ud.id] = true
			out.append(ud)
	return out

# 결과:
#   {
#     "class_count": { Class enum 값 -> int },
#     "race_count":  { Race enum 값  -> int },
#     "active_class": Array[Dictionary{def, count, step}],
#     "active_race":  Array[Dictionary{def, count, step}],
#     "all_class":    Array[Dictionary{def, count, step}],   # step==0 포함 (정의 있는 것만)
#     "all_race":     Array[Dictionary{def, count, step}],
#   }
static func calc(unique_types: Array[UnitData]) -> Dictionary:
	var class_count: Dictionary = {}
	var race_count: Dictionary = {}
	for ud in unique_types:
		if ud == null:
			continue
		var c: int = ud.unit_class
		var r: int = ud.race
		class_count[c] = int(class_count.get(c, 0)) + 1
		race_count[r] = int(race_count.get(r, 0)) + 1

	var all_class := _resolve(class_count, GameEnums.SynergyType.CLASS)
	var all_race := _resolve(race_count, GameEnums.SynergyType.RACE)
	return {
		"class_count": class_count,
		"race_count": race_count,
		"active_class": all_class.filter(func(e): return int(e.step) > 0),
		"active_race": all_race.filter(func(e): return int(e.step) > 0),
		"all_class": all_class,
		"all_race": all_race,
	}

static func _resolve(count_dict: Dictionary, type: GameEnums.SynergyType) -> Array:
	var arr: Array = []
	for key in count_dict.keys():
		var cnt: int = count_dict[key]
		var def: SynergyDef = SynergyDB.get_by_type_key(type, key)
		if def == null:
			continue
		arr.append({
			"def": def,
			"count": cnt,
			"step": def.step_for_count(cnt),
		})
	arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: int = a["step"]
		var sb: int = b["step"]
		if sa != sb:
			return sa > sb
		var ca: int = a["count"]
		var cb: int = b["count"]
		return ca > cb
	)
	return arr
