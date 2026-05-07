class_name PrepCoordMapper
extends RefCounted

# PREP phase의 좌표 변환 책임을 담당.
# 셀 인덱스 ↔ 셀 좌상단/중심, 사분면 오프셋 계산.
# PlayerZone Control 참조와 그리드 차원만 받아 모든 좌표를 산출한다.

const SUB_GRID_COLS: int = 2
const SUB_GRID_ROWS: int = 2
const SUB_GRID_CAPACITY: int = SUB_GRID_COLS * SUB_GRID_ROWS  # 4

var _zone: Control
var _grid_cols: int
var _grid_rows: int

func _init(zone: Control, grid_cols: int, grid_rows: int) -> void:
	_zone = zone
	_grid_cols = grid_cols
	_grid_rows = grid_rows

func cell_size() -> Vector2:
	var zone_size: Vector2 = _zone.size
	return Vector2(zone_size.x / float(_grid_cols), zone_size.y / float(_grid_rows))

func cell_origin(cell_idx: int) -> Vector2:
	var col: int = cell_idx % _grid_cols
	var row: int = cell_idx / _grid_cols
	var cs: Vector2 = cell_size()
	return Vector2(float(col) * cs.x, float(row) * cs.y)

func cell_center(cell_idx: int) -> Vector2:
	return cell_origin(cell_idx) + cell_size() * 0.5

# 셀 내부 서브그리드 중심까지의 상대 오프셋. SUB_GRID_COLS x SUB_GRID_ROWS 차원에 일반화.
# count == 1 → 중심(원점)에 단일 큰 토큰.
# count 2~CAPACITY → 슬롯 순서대로 서브셀 중심에 채움.
# count > CAPACITY → 같은 슬롯을 다시 순회하며 작은 지터로 겹침 방지.
func sub_cell_offset(idx: int, total: int, cs: Vector2) -> Vector2:
	if total <= 1:
		return Vector2.ZERO
	var slot: int = idx % SUB_GRID_CAPACITY
	var layer: int = idx / SUB_GRID_CAPACITY
	var col: int = slot % SUB_GRID_COLS
	var row: int = slot / SUB_GRID_COLS
	# 서브셀 중심 = 셀 중심에서 ((col+0.5)/SUB_COLS - 0.5) * 셀너비.
	var qx: float = ((float(col) + 0.5) / float(SUB_GRID_COLS) - 0.5) * cs.x
	var qy: float = ((float(row) + 0.5) / float(SUB_GRID_ROWS) - 0.5) * cs.y
	# layer >= 1 (CAPACITY 초과분)은 같은 서브셀 안쪽에서 시계방향으로 약간 비틀어 겹침 방지.
	if layer > 0:
		var jitter_radius: float = min(cs.x, cs.y) * 0.08
		var angle: float = float(layer) * (TAU / 8.0)
		qx += cos(angle) * jitter_radius
		qy += sin(angle) * jitter_radius
	return Vector2(qx, qy)
