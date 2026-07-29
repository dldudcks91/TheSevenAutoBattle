class_name DeploymentBoard
extends RefCounted

# 덱빌딩 모델의 임시 배치판 — 3×3, 1칸 1유닛. 매 전투 초기화된다 (GAME_DESIGN §4).
# 배치는 예산 상한 + 칸 상한이라는 이중 제약을 받는다: 칸이 다 차면 남는 예산이 강화로 밀린다.
# paid/unpaid·영구 그리드 개념은 폐기 — 배치는 골드가 아니라 budget 만 소모한다.
#
# 각 셀 = null 또는 { "card": Card, "mods": Array }  (mods = 부착된 시한부 강화 카드들)

const GRID_CELLS_TOTAL: int = 9   # 3×3

var cells: Array = []
var budget_total: int = 10
var budget_spent: int = 0

# 매 전투 준비 시 판을 비우고 예산을 새로 설정.
func reset(new_budget: int) -> void:
	cells.clear()
	for _i in GRID_CELLS_TOTAL:
		cells.append(null)
	budget_total = new_budget
	budget_spent = 0

func ensure() -> void:
	if cells.size() != GRID_CELLS_TOTAL:
		reset(budget_total)

func budget_left() -> int:
	return budget_total - budget_spent

func can_place(cost: int) -> bool:
	return cost <= budget_left()

func is_empty_cell(cell_idx: int) -> bool:
	return _valid(cell_idx) and cells[cell_idx] == null

func _valid(cell_idx: int) -> bool:
	return cell_idx >= 0 and cell_idx < GRID_CELLS_TOTAL

# 병사 카드를 빈 칸에 배치. 성공 시 예산 차감.
func place_soldier(cell_idx: int, card: Card) -> bool:
	if not _valid(cell_idx) or cells[cell_idx] != null:
		return false
	if not can_place(card.cost):
		return false
	cells[cell_idx] = {"card": card, "mods": []}
	budget_spent += card.cost
	return true

# 시한부 강화를 이미 배치된 병사에 부착. 성공 시 예산 차감. (부착 상한 없음 — 미결)
func attach_mod(cell_idx: int, card: Card) -> bool:
	if not _valid(cell_idx) or cells[cell_idx] == null:
		return false
	if not can_place(card.cost):
		return false
	var entry: Dictionary = cells[cell_idx]
	(entry["mods"] as Array).append(card)
	budget_spent += card.cost
	return true

# 셀 회수 — 병사 + 부착 강화 전부 반환하고 예산 환급. 반환 카드 목록을 돌려준다(핸드 복귀용).
func remove_cell(cell_idx: int) -> Array:
	if not _valid(cell_idx) or cells[cell_idx] == null:
		return []
	var entry: Dictionary = cells[cell_idx]
	var freed: Array = []
	var card: Card = entry["card"]
	freed.append(card)
	budget_spent -= card.cost
	for m in (entry["mods"] as Array):
		freed.append(m)
		budget_spent -= (m as Card).cost
	cells[cell_idx] = null
	return freed

func cell_at(cell_idx: int):
	if not _valid(cell_idx):
		return null
	return cells[cell_idx]

func soldier_count() -> int:
	var n := 0
	for e in cells:
		if e != null:
			n += 1
	return n

# 배치된 모든 카드(병사 + 부착 강화) — 전투 후 회수용.
func all_played_cards() -> Array:
	var out: Array = []
	for e in cells:
		if e == null:
			continue
		out.append(e["card"])
		for m in (e["mods"] as Array):
			out.append(m)
	return out
