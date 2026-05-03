class_name EnemyPreviewView
extends RefCounted

# 적 진영 프리뷰 렌더러. EnemyZone(셸 슬롯)에 적 토큰과 진형 라벨을 그린다.
# 입력 처리 없음 — 순수 시각 컴포넌트.

# "적 진영" 글씨 바로 아래 전술 라벨 영역 높이.
const TACTIC_LABEL_H: float = 44.0

# token_factory: Callable(unit_data: UnitData, pos: Vector2, is_enemy: bool) -> Node
# prep_phase의 static _make_field_token을 위로 주입한다.
static func render(zone: Control, lineup: Array, tactic_key: StringName, token_factory: Callable) -> void:
	for c in zone.get_children():
		c.queue_free()

	var zone_w: float = zone.size.x if zone.size.x > 0.0 else 360.0
	var zone_h: float = zone.size.y if zone.size.y > 0.0 else 360.0

	# 전술 라벨
	var tactic_lbl := Label.new()
	tactic_lbl.text = FormationLibrary.label_for(tactic_key)
	tactic_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tactic_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tactic_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tactic_lbl.add_theme_font_size_override("font_size", 14)
	tactic_lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.42))
	tactic_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tactic_lbl.size = Vector2(zone_w, TACTIC_LABEL_H)
	tactic_lbl.position = Vector2(0.0, 0.0)
	zone.add_child(tactic_lbl)

	var n: int = lineup.size()
	if n == 0:
		return

	var field_h: float = zone_h - TACTIC_LABEL_H
	var positions: Array = FormationLibrary.positions_for(tactic_key, n, zone_w, field_h)

	for i in n:
		var d: UnitData = lineup[i] as UnitData
		if d == null:
			continue
		var pos: Vector2 = positions[i] + Vector2(0.0, TACTIC_LABEL_H)
		zone.add_child(token_factory.call(d, pos, true))

		var name_lbl := Label.new()
		name_lbl.text = TranslationServer.translate(d.name_key)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.modulate = Color(0.95, 0.6, 0.6)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.size = Vector2(120.0, 20.0)
		name_lbl.position = pos + Vector2(-60.0, 34.0)
		zone.add_child(name_lbl)
