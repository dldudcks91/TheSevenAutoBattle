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

# 셀 내부 사분면(2×2) 중심까지의 상대 오프셋.
# count == 1 → 중심(원점)에 단일 큰 토큰.
# count 2~4  → 사분면 0=좌상, 1=우상, 2=좌하, 3=우하 순으로 채움.
# count > 4  → 5번째부터는 사분면을 다시 순회하며 작은 지터를 더해 시각적으로 겹치지 않게.
func sub_cell_offset(idx: int, total: int, cs: Vector2) -> Vector2:
	if total <= 1:
		return Vector2.ZERO
	var slot: int = idx % SUB_GRID_CAPACITY
	var layer: int = idx / SUB_GRID_CAPACITY
	var col: int = slot % SUB_GRID_COLS
	var row: int = slot / SUB_GRID_COLS
	# 사분면 중심 = 셀 중심에서 ±cell_size/4.
	var qx: float = (-0.25 + float(col) * 0.5) * cs.x
	var qy: float = (-0.25 + float(row) * 0.5) * cs.y
	# layer >= 1 (5번째 이상)은 같은 사분면 안쪽에서 시계방향으로 약간 비틀어 겹침 방지.
	if layer > 0:
		var jitter_radius: float = min(cs.x, cs.y) * 0.08
		var angle: float = float(layer) * (TAU / 8.0)
		qx += cos(angle) * jitter_radius
		qy += sin(angle) * jitter_radius
	return Vector2(qx, qy)
