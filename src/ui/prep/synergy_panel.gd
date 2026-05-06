class_name SynergyPanel
extends PanelContainer

# SHOP 단계 시너지 발동 단계를 실시간으로 보여주는 좌상단 패널.
# prep_phase가 그리드 변경 시 update_from_grid() 호출.

var _class_box: VBoxContainer
var _race_box: VBoxContainer

func _ready() -> void:
	custom_minimum_size = Vector2(220, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	margin.add_child(v)

	v.add_child(_make_section_title(&"SYNERGY_HEADER_CLASS"))
	_class_box = VBoxContainer.new()
	_class_box.add_theme_constant_override("separation", 2)
	v.add_child(_class_box)

	var sep := HSeparator.new()
	v.add_child(sep)

	v.add_child(_make_section_title(&"SYNERGY_HEADER_RACE"))
	_race_box = VBoxContainer.new()
	_race_box.add_theme_constant_override("separation", 2)
	v.add_child(_race_box)

func update_from_grid(grid_cells: Array) -> void:
	_clear(_class_box)
	_clear(_race_box)
	var unique: Array[UnitData] = SynergyCalculator.unique_types_from_grid(grid_cells)
	var result: Dictionary = SynergyCalculator.calc(unique)
	for entry in (result["all_class"] as Array):
		_class_box.add_child(_make_synergy_label(entry as Dictionary))
	for entry in (result["all_race"] as Array):
		_race_box.add_child(_make_synergy_label(entry as Dictionary))

func _make_section_title(key: StringName) -> Label:
	var lbl := Label.new()
	lbl.text = TranslationServer.translate(key)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.modulate = Color(0.85, 0.85, 0.85)
	return lbl

func _make_synergy_label(entry: Dictionary) -> Label:
	var def: SynergyDef = entry["def"]
	var count: int = entry["count"]
	var step: int = entry["step"]
	var max_step: int = def.max_step()
	var nm: String = TranslationServer.translate(def.name_key)
	var stars: String = "★".repeat(step) + "☆".repeat(max(0, max_step - step))
	var next_t: int = def.next_threshold(count)
	var suffix: String = ""
	if next_t > 0:
		suffix = "  →%d" % next_t
	var lbl := Label.new()
	lbl.text = "%s  %s  %d%s" % [stars, nm, count, suffix]
	if step == 0:
		lbl.modulate = Color(0.55, 0.55, 0.55, 0.85)
	else:
		lbl.modulate = Color(1.0, 0.85, 0.3)
	return lbl

static func _clear(box: VBoxContainer) -> void:
	for c in box.get_children():
		c.queue_free()
