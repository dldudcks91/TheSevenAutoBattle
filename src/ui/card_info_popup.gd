class_name CardInfoPopup
extends Control

# 핸드 카드(아이템/스킬/강화) 클릭 시 우측에 띄우는 정보 패널.
# HeroInfoPopup과 동일한 위치·방식으로 표시되며, 동시에 열리지 않는다.

signal close_requested

const _NAME_FONT := 20
const _ROW_FONT := 16
const _MUTED := Color(0.65, 0.65, 0.72)
const _SUB := Color(0.78, 0.82, 0.88)

var _type_lbl: Label
var _name_lbl: Label
var _desc_lbl: Label
var _cost_lbl: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	hide()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.layout_mode = 1
	panel.anchors_preset = 0
	panel.offset_left = 672.0
	panel.offset_top = 220.0
	panel.offset_right = 952.0
	panel.offset_bottom = 490.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	_type_lbl = Label.new()
	_type_lbl.add_theme_font_size_override("font_size", 14)
	header.add_child(_type_lbl)

	_name_lbl = Label.new()
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_lbl.add_theme_font_size_override("font_size", _NAME_FONT)
	header.add_child(_name_lbl)

	vbox.add_child(HSeparator.new())

	_desc_lbl = Label.new()
	_desc_lbl.add_theme_font_size_override("font_size", _ROW_FONT)
	_desc_lbl.add_theme_color_override("font_color", _SUB)
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.custom_minimum_size = Vector2(0, 48)
	vbox.add_child(_desc_lbl)

	vbox.add_child(HSeparator.new())

	var cost_row := HBoxContainer.new()
	vbox.add_child(cost_row)

	var cost_key := Label.new()
	cost_key.text = "비용"
	cost_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_key.add_theme_font_size_override("font_size", _ROW_FONT)
	cost_key.add_theme_color_override("font_color", _MUTED)
	cost_row.add_child(cost_key)

	_cost_lbl = Label.new()
	_cost_lbl.add_theme_font_size_override("font_size", _ROW_FONT)
	_cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	cost_row.add_child(_cost_lbl)

func show_for(slot: RosterSlot, kind_label: String, accent: Color) -> void:
	_type_lbl.text = "[%s]" % kind_label
	_type_lbl.add_theme_color_override("font_color", accent)
	_name_lbl.text = slot.dummy_name
	if slot.item_data != null:
		var stat_name := ""
		match slot.item_data.stat_key:
			ItemData.StatKey.ATTACK:     stat_name = "공격"
			ItemData.StatKey.HP:         stat_name = "HP"
			ItemData.StatKey.ARMOR:      stat_name = "방어"
			ItemData.StatKey.MOVE_SPEED: stat_name = "이동속도"
		_desc_lbl.text = "%s +%s" % [stat_name, str(slot.item_data.value)]
	else:
		_desc_lbl.text = slot.dummy_desc if not slot.dummy_desc.is_empty() else "—"
	_cost_lbl.text = "%d g" % slot.dummy_price
	show()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()
		accept_event()
