extends Control
class_name PlacementZone

signal place_requested(slot_idx: int, cell_idx: int)
signal swap_requested(from_idx: int, to_idx: int)
signal drag_started(from_idx: int)
signal drag_ended
signal cell_clicked(cell_idx: int)

const GRID_COLS := 3
const GRID_ROWS := 3
# 좌클릭 press~release 사이 이동 거리가 이 값 이하이면 "클릭", 초과면 드래그 의도로 본다.
const CLICK_MAX_TRAVEL_PX := 6.0

# prep_phase가 주입: 셀에 유닛이 있는지 / 드래그 프리뷰 빌더 / 핸드카드 드롭 허용 여부
var get_cell_has_unit: Callable = Callable()
var build_drag_preview: Callable = Callable()
var can_drop_hand_card: Callable = Callable()  # (slot_idx: int, cell_idx: int) -> bool

# 좌클릭 추적 — 짧은 클릭은 cell_clicked, 긴 드래그는 _get_drag_data가 가져간다.
var _press_cell: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _drag_in_progress: bool = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_cell = _cell_at(event.position)
				_press_pos = event.position
			else:
				# release: 같은 셀 안에서 짧은 클릭이고 드래그가 시작되지 않았다면 cell_clicked.
				var rel_idx: int = _cell_at(event.position)
				var travel: float = event.position.distance_to(_press_pos)
				if (not _drag_in_progress
						and _press_cell >= 0
						and rel_idx == _press_cell
						and travel <= CLICK_MAX_TRAVEL_PX):
					cell_clicked.emit(rel_idx)
				_press_cell = -1

func _get_drag_data(at_position: Vector2) -> Variant:
	var idx: int = _cell_at(at_position)
	if idx < 0:
		return null
	if get_cell_has_unit.is_valid() and not bool(get_cell_has_unit.call(idx)):
		return null
	var preview: Control = null
	if build_drag_preview.is_valid():
		preview = build_drag_preview.call(idx, at_position) as Control
	if preview == null:
		var rect := ColorRect.new()
		rect.color = Color(0.4, 0.7, 1.0, 0.4)
		rect.size = Vector2(72, 72)
		preview = rect
	set_drag_preview(preview)
	_drag_in_progress = true
	drag_started.emit(idx)
	return {"swap_from": idx}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drag_in_progress = false
		drag_ended.emit()

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var dict: Dictionary = data as Dictionary
	var to_idx: int = _cell_at(at_position)
	if to_idx < 0:
		return false
	if dict.has("hand_slot"):
		if can_drop_hand_card.is_valid():
			return bool(can_drop_hand_card.call(int(dict["hand_slot"]), to_idx))
		return true
	if dict.has("swap_from"):
		return to_idx != int(dict["swap_from"])
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var to_idx: int = _cell_at(at_position)
	if to_idx < 0:
		return
	var dict: Dictionary = data as Dictionary
	if dict.has("swap_from"):
		swap_requested.emit(int(dict["swap_from"]), to_idx)
	elif dict.has("hand_slot"):
		place_requested.emit(int(dict["hand_slot"]), to_idx)

func _cell_at(local_pos: Vector2) -> int:
	if size.x <= 0.0 or size.y <= 0.0:
		return -1
	if local_pos.x < 0.0 or local_pos.y < 0.0 or local_pos.x >= size.x or local_pos.y >= size.y:
		return -1
	var col: int = int(local_pos.x / (size.x / float(GRID_COLS)))
	var row: int = int(local_pos.y / (size.y / float(GRID_ROWS)))
	col = clampi(col, 0, GRID_COLS - 1)
	row = clampi(row, 0, GRID_ROWS - 1)
	return row * GRID_COLS + col
