class_name SynergyChip
extends RefCounted

# 유닛의 종족·직업을 작은 칩(태그)으로 표시하는 공용 위젯 빌더.
# unit_detail_card / hero_info_popup 등 유닛 카드 UI에서 공용으로 쓴다.

const RACE_COLOR := Color(0.40, 0.78, 1.00)     # cyan
const CLASS_COLOR := Color(1.00, 0.82, 0.45)    # gold

const _FONT_SIZE := 12

static func make_row_for(ud: UnitData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.add_child(_make(_label_for_race(ud.race), RACE_COLOR))
	row.add_child(_make(_label_for_class(ud.unit_class), CLASS_COLOR))
	return row

static func _label_for_race(race: int) -> String:
	var key: String = "RACE_" + str(GameEnums.Race.find_key(race))
	return TranslationServer.translate(key)

static func _label_for_class(klass: int) -> String:
	var key: String = "CLASS_" + str(GameEnums.Class.find_key(klass))
	return TranslationServer.translate(key)

static func _make(text: String, accent: Color) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.18)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	pc.add_theme_stylebox_override(&"panel", sb)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override(&"font_size", _FONT_SIZE)
	lbl.add_theme_color_override(&"font_color", accent.lightened(0.25))
	pc.add_child(lbl)
	return pc
