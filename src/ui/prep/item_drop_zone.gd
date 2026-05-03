extends Control
class_name ItemDropZone

signal item_dropped(slot_idx: int)

# (slot_idx: int) -> bool  — 외부에서 주입. 유효한 아이템 카드인지 확인.
var can_drop_item: Callable

const _ACCENT := Color(0.55, 0.85, 0.65)

var _hover_border: ReferenceRect = null

func _ready() -> void:
	_hover_border = ReferenceRect.new()
	_hover_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hover_border.border_color = _ACCENT
	_hover_border.border_width = 3.0
	_hover_border.editor_only = false
	_hover_border.visible = false
	_hover_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hover_border)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if _hover_border != null:
			_hover_border.visible = false

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var dict: Dictionary = data as Dictionary
	if not dict.has("hand_slot"):
		return false
	var ok := false
	if can_drop_item.is_valid():
		ok = bool(can_drop_item.call(int(dict["hand_slot"])))
	if _hover_border != null:
		_hover_border.visible = ok
	return ok

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _hover_border != null:
		_hover_border.visible = false
	var dict: Dictionary = data as Dictionary
	item_dropped.emit(int(dict["hand_slot"]))
