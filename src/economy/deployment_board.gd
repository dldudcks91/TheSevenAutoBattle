class_name DeploymentBoard
extends RefCounted

# 3x3 영구 그리드 상태와 paid/unpaid 회계.
# 각 셀은 {slot: RosterSlot, paid: bool, hand_idx: int} Dictionary 배열.

const GRID_CELLS_TOTAL: int = 9
const MAX_UPGRADE_LEVEL: int = 3

var grid_cells: Array = []
# 셀별 스탯 보정 카운트. {"atk": int, "hp": int, "armor": int} 형태.
# 각 값은 해당 스탯에 적용된 업그레이드 횟수. 합계가 MAX_UPGRADE_LEVEL 이하여야 한다.
var grid_cell_boosts: Array = []

func ensure_grid() -> void:
	if grid_cells.size() != GRID_CELLS_TOTAL:
		grid_cells.clear()
		grid_cell_boosts.clear()
		for _i in GRID_CELLS_TOTAL:
			grid_cells.append([])
			grid_cell_boosts.append({})
		return
	for i in GRID_CELLS_TOTAL:
		if not (grid_cells[i] is Array):
			grid_cells[i] = []
	if grid_cell_boosts.size() != GRID_CELLS_TOTAL:
		grid_cell_boosts.clear()
		for _i in GRID_CELLS_TOTAL:
			grid_cell_boosts.append({})

func clear() -> void:
	grid_cells.clear()
	grid_cell_boosts.clear()
	ensure_grid()

func get_cell_boost_count(cell_idx: int) -> int:
	if cell_idx < 0 or cell_idx >= GRID_CELLS_TOTAL:
		return 0
	var total: int = 0
	for v in grid_cell_boosts[cell_idx].values():
		total += int(v)
	return total

func get_cell_boosts(cell_idx: int) -> Dictionary:
	if cell_idx < 0 or cell_idx >= GRID_CELLS_TOTAL:
		return {}
	return grid_cell_boosts[cell_idx].duplicate()

func add_cell_boost(cell_idx: int, stat: String) -> bool:
	if cell_idx < 0 or cell_idx >= GRID_CELLS_TOTAL:
		return false
	if get_cell_boost_count(cell_idx) >= MAX_UPGRADE_LEVEL:
		return false
	var d: Dictionary = grid_cell_boosts[cell_idx]
	d[stat] = int(d.get(stat, 0)) + 1
	return true

func clear_cell_boosts(cell_idx: int) -> void:
	if cell_idx < 0 or cell_idx >= GRID_CELLS_TOTAL:
		return
	grid_cell_boosts[cell_idx].clear()

func swap_cell_boosts(idx_a: int, idx_b: int) -> void:
	if idx_a < 0 or idx_a >= GRID_CELLS_TOTAL:
		return
	if idx_b < 0 or idx_b >= GRID_CELLS_TOTAL:
		return
	var tmp: Dictionary = grid_cell_boosts[idx_a]
	grid_cell_boosts[idx_a] = grid_cell_boosts[idx_b]
	grid_cell_boosts[idx_b] = tmp

func total_count() -> int:
	var total: int = 0
	for i in GRID_CELLS_TOTAL:
		total += (grid_cells[i] as Array).size()
	return total

func unpaid_cost(hire_price_resolver: Callable) -> int:
	var total: int = 0
	for i in GRID_CELLS_TOTAL:
		var entries: Array = grid_cells[i]
		for entry in entries:
			var d: Dictionary = entry as Dictionary
			if not bool(d.get("paid", false)):
				total += int(hire_price_resolver.call((d["slot"] as RosterSlot).unit_data))
	return total

func unpaid_count() -> int:
	var total: int = 0
	for i in GRID_CELLS_TOTAL:
		var entries: Array = grid_cells[i]
		for entry in entries:
			if not bool((entry as Dictionary).get("paid", false)):
				total += 1
	return total

# 모든 unpaid entry를 paid로 확정 + hand_idx 무효화. "전투 시작" 시점에 호출.
func commit_paid() -> void:
	for i in GRID_CELLS_TOTAL:
		var entries: Array = grid_cells[i]
		for entry in entries:
			var d: Dictionary = entry as Dictionary
			d["paid"] = true
			d["hand_idx"] = -1

# 리롤 시 hand 풀이 갈아엎혀 hand_idx 의미 소실 — 모든 unpaid의 hand_idx를 -1로.
func invalidate_unpaid_hand_indices() -> void:
	for i in GRID_CELLS_TOTAL:
		var entries: Array = grid_cells[i]
		for entry in entries:
			var d: Dictionary = entry as Dictionary
			if not bool(d.get("paid", false)):
				d["hand_idx"] = -1
