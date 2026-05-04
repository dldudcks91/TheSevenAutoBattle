class_name ItemInventoryView
extends RefCounted

# 아이템 인벤토리 패널 렌더러. 셸의 ItemSlot에 PanelContainer + GridContainer를 채운다.
# 입력 처리 없음 — 순수 시각 컴포넌트(추후 클릭/장착 추가 시에도 시그널만 노출).

const ACCENT := Color(0.55, 0.85, 0.65)  # teal-green
const BOX_COUNT: int = 10
const BOX_SIZE: int = 96
const GRID_COLS: int = 5

static func render(slot: Control, inventory: Array) -> void:
	for c in slot.get_children():
		c.queue_free()

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "아이템 인벤토리"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", ACCENT.lightened(0.2))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)

	for i in BOX_COUNT:
		var item: ItemData = inventory[i] if i < inventory.size() else null
		grid.add_child(_make_card(item))

static func _make_card(item: ItemData) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(BOX_SIZE, BOX_SIZE)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	if item == null:
		sb.bg_color = Color(0.09, 0.10, 0.15)
		sb.border_color = Color(0.28, 0.30, 0.42, 0.7)
	else:
		sb.bg_color = Color(0.13, 0.15, 0.22)
		sb.border_color = ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", sb)

	if item == null:
		return card

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var glyph := Label.new()
	glyph.text = "◆"
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 22)
	glyph.add_theme_color_override("font_color", ACCENT)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(glyph)

	var name_lbl := Label.new()
	name_lbl.text = TranslationServer.translate(item.name_key)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.92, 0.95))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var stat_name := ""
	match item.stat_key:
		ItemData.StatKey.ATTACK:     stat_name = "공격"
		ItemData.StatKey.HP:         stat_name = "HP"
		ItemData.StatKey.DEFENSE:    stat_name = "방어"
		ItemData.StatKey.MOVE_SPEED: stat_name = "이동속도"
	var stat_lbl := Label.new()
	stat_lbl.text = "+%s %s" % [str(item.value), stat_name]
	stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_lbl.add_theme_font_size_override("font_size", 11)
	stat_lbl.add_theme_color_override("font_color", Color(0.70, 0.92, 0.75))
	stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stat_lbl)

	return card
