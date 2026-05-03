class_name HeroInfoPopup
extends Control

# 그리드에 배치된 영웅 토큰 클릭 시 우측에 띄우는 정보 패널.
# - 풀 스탯(HP/ATK/ARM/SPD/사거리/공격간격) + 직업 + 기본 스킬 + 장착 아이템.
# - 닫기: 팝업 패널 밖 빈 곳 좌클릭 (PlacementZone과 HandCard는 자체 입력 캡처).
# - 다른 영웅 클릭 시 prep_phase가 show_for를 다시 호출해 내용만 교체.

signal close_requested

const _ROW_FONT := 16
const _HEADER_FONT := 22
const _SKILL_NAME_FONT := 18
const _ACCENT := Color(0.55, 0.72, 0.95)
const _SUB := Color(0.78, 0.82, 0.88)
const _MUTED := Color(0.65, 0.65, 0.72)
const _STAR_COLOR := Color(1.0, 0.85, 0.0)

@onready var _name_lbl: Label = $Panel/Margin/VBox/Header/NameLbl
@onready var _job_lbl: Label = $Panel/Margin/VBox/Header/JobLbl
@onready var _stat_grid: GridContainer = $Panel/Margin/VBox/StatGrid
@onready var _skill_name_lbl: Label = $Panel/Margin/VBox/SkillBox/SkillName
@onready var _skill_desc_lbl: Label = $Panel/Margin/VBox/SkillBox/SkillDesc
@onready var _skill_name2_lbl: Label = $Panel/Margin/VBox/SkillBox2/SkillName2
@onready var _skill_desc2_lbl: Label = $Panel/Margin/VBox/SkillBox2/SkillDesc2
@onready var _skill_name3_lbl: Label = $Panel/Margin/VBox/SkillBox3/SkillName3
@onready var _skill_desc3_lbl: Label = $Panel/Margin/VBox/SkillBox3/SkillDesc3

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 루트는 입력을 통과시켜야 그리드/핸드 클릭이 가능.
	hide()

func show_for(slot: RosterSlot, boosts: Dictionary = {}, inventory: Array = []) -> void:
	if slot == null or slot.unit_data == null:
		hide()
		return
	var ud: UnitData = slot.unit_data
	_name_lbl.text = tr(ud.name_key)
	var total_upgrades: int = 0
	for v in boosts.values():
		total_upgrades += int(v)
	if total_upgrades > 0:
		_job_lbl.text = "★".repeat(total_upgrades)
		_job_lbl.add_theme_color_override("font_color", _STAR_COLOR)
		_job_lbl.add_theme_font_size_override("font_size", _HEADER_FONT)
	else:
		_job_lbl.text = ""
	var item_bonuses: Dictionary = _compute_item_bonuses(slot, inventory)
	_fill_stat_grid(ud, boosts, item_bonuses)
	_fill_skill(ud.default_skill_id)
	_fill_empty_skill_slot(_skill_name2_lbl, _skill_desc2_lbl)
	_fill_empty_skill_slot(_skill_name3_lbl, _skill_desc3_lbl)
	show()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()
		accept_event()

const _ITEM_BONUS_COLOR := Color(0.4, 0.75, 1.0)  # 파란색 — 아이템 보너스
const _UPGRADE_BONUS_COLOR := Color(0.3, 0.9, 0.4)  # 초록색 — 업그레이드 보너스

# ─── helpers ──────────────────────────────────────────────────────────────
func _compute_item_bonuses(slot: RosterSlot, inventory: Array) -> Dictionary:
	var b := {"attack": 0.0, "hp": 0.0, "armor": 0.0, "move_speed": 0.0}
	var unit_id: StringName = slot.unit_data.id if slot.unit_data != null else &""
	for it in slot.items:
		_add_item_bonus(b, it)
	for raw_it in inventory:
		if not (raw_it is ItemData):
			continue
		var it: ItemData = raw_it as ItemData
		var applies := false
		match it.scope:
			ItemData.Scope.ALL_ALLIES: applies = true
			ItemData.Scope.UNIT: applies = (it.condition_unit_id == unit_id)
		if applies:
			_add_item_bonus(b, it)
	return b

func _add_item_bonus(b: Dictionary, it: ItemData) -> void:
	match it.stat_key:
		ItemData.StatKey.ATTACK:     b["attack"]     += it.value
		ItemData.StatKey.HP:         b["hp"]         += it.value
		ItemData.StatKey.ARMOR:      b["armor"]      += it.value
		ItemData.StatKey.MOVE_SPEED: b["move_speed"] += it.value

func _fill_stat_grid(ud: UnitData, boosts: Dictionary = {}, item_bonuses: Dictionary = {}) -> void:
	for c in _stat_grid.get_children():
		c.queue_free()
	var range_text: String = "%d (%s)" % [ud.attack_range, tr(&"LABEL_RANGED" if ud.is_ranged else &"LABEL_MELEE")]
	var atk_boost: int = int(boosts.get("atk", 0))
	var hp_boost: int = int(boosts.get("hp", 0))
	var arm_boost: int = int(boosts.get("armor", 0))
	var atk_item: float = float(item_bonuses.get("attack", 0.0))
	var hp_item: float = float(item_bonuses.get("hp", 0.0))
	var arm_item: float = float(item_bonuses.get("armor", 0.0))
	var spd_item: float = float(item_bonuses.get("move_speed", 0.0))
	# [label, base_text, has_upgrade, upgrade_text, has_item, item_text]
	var rows: Array = [
		[tr(&"LABEL_HP"),  str(int(ud.max_hp)),     hp_boost > 0,  "(+%d)" % int(hp_boost * EffectiveStats.UPGRADE_HP_VALUE),    hp_item > 0.0,  "(+%d)" % int(hp_item)],
		[tr(&"LABEL_ATK"), str(int(ud.attack)),      atk_boost > 0, "(+%d)" % int(atk_boost * EffectiveStats.UPGRADE_ATK_VALUE),  atk_item > 0.0, "(+%d)" % int(atk_item)],
		[tr(&"LABEL_DEF"), str(int(ud.armor)),       arm_boost > 0, "(+%d)" % int(arm_boost * EffectiveStats.UPGRADE_ARMOR_VALUE),arm_item > 0.0, "(+%d)" % int(arm_item)],
		[tr(&"LABEL_SPD"), str(int(ud.move_speed)), false, "",                                                                    spd_item > 0.0, "(+%d)" % int(spd_item)],
		[tr(&"LABEL_RANGE"), range_text,             false, "",                                                                    false, ""],
		[tr(&"LABEL_INTERVAL"), "%.2fs" % ud.attack_interval, false, "",                                                          false, ""],
	]
	for row in rows:
		var k_lbl := Label.new()
		k_lbl.text = row[0] as String
		k_lbl.add_theme_font_size_override("font_size", _ROW_FONT)
		k_lbl.add_theme_color_override("font_color", _MUTED)
		_stat_grid.add_child(k_lbl)

		var has_upgrade: bool = bool(row[2])
		var has_item: bool = bool(row[4])
		if has_upgrade or has_item:
			var container := HBoxContainer.new()
			container.add_theme_constant_override("separation", 2)
			var base_lbl := Label.new()
			base_lbl.text = row[1] as String
			base_lbl.add_theme_font_size_override("font_size", _ROW_FONT)
			base_lbl.add_theme_color_override("font_color", _SUB)
			container.add_child(base_lbl)
			if has_upgrade:
				var upgrade_lbl := Label.new()
				upgrade_lbl.text = row[3] as String
				upgrade_lbl.add_theme_font_size_override("font_size", _ROW_FONT)
				upgrade_lbl.add_theme_color_override("font_color", _UPGRADE_BONUS_COLOR)
				container.add_child(upgrade_lbl)
			if has_item:
				var item_lbl := Label.new()
				item_lbl.text = row[5] as String
				item_lbl.add_theme_font_size_override("font_size", _ROW_FONT)
				item_lbl.add_theme_color_override("font_color", _ITEM_BONUS_COLOR)
				container.add_child(item_lbl)
			_stat_grid.add_child(container)
		else:
			var v_lbl := Label.new()
			v_lbl.text = row[1] as String
			v_lbl.add_theme_font_size_override("font_size", _ROW_FONT)
			v_lbl.add_theme_color_override("font_color", _SUB)
			_stat_grid.add_child(v_lbl)

func _fill_skill(skill_id: StringName) -> void:
	if String(skill_id).is_empty():
		_skill_name_lbl.text = tr(&"LABEL_NONE")
		_skill_desc_lbl.text = ""
		return
	var sd: SkillData = SkillDB.get_by_id(skill_id)
	if sd == null:
		_skill_name_lbl.text = String(skill_id)
		_skill_desc_lbl.text = ""
		return
	_skill_name_lbl.text = tr(sd.name_key)
	_skill_desc_lbl.text = tr(sd.desc_key)

func _fill_empty_skill_slot(name_lbl: Label, desc_lbl: Label) -> void:
	name_lbl.text = "—"
	name_lbl.add_theme_color_override("font_color", _MUTED)
	desc_lbl.text = ""

func _job_key(job: int) -> StringName:
	match job:
		GameEnums.Job.SOLDIER:   return &"JOB_SOLDIER"
		GameEnums.Job.AXEMAN:    return &"JOB_AXEMAN"
		GameEnums.Job.SWORDSMAN: return &"JOB_SWORDSMAN"
		GameEnums.Job.KNIGHT:    return &"JOB_KNIGHT"
		GameEnums.Job.TEMPLAR:   return &"JOB_TEMPLAR"
		GameEnums.Job.LANCER:    return &"JOB_LANCER"
		GameEnums.Job.ARCHER:    return &"JOB_ARCHER"
		GameEnums.Job.PRIEST:    return &"JOB_PRIEST"
		GameEnums.Job.WIZARD:    return &"JOB_WIZARD"
	return &"JOB_SOLDIER"
