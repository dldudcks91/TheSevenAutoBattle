class_name EffectiveStats
extends RefCounted

# Computed battle stats for a spawned unit. UnitData stays read-only baseline;
# items attached at the RosterSlot (type) level are summed here once per slot
# and shared by every instance of that type spawned in a battle.

# 업그레이드 카드 1회 적용 시 더해지는 스탯 양.
const UPGRADE_ATK_VALUE: float = 10.0
const UPGRADE_HP_VALUE: float = 50.0
const UPGRADE_ARMOR_VALUE: float = 2.0

var max_hp: float
var attack: float
var attack_range: float
var attack_interval: float
var move_speed: float
var armor: float

# 셀 업그레이드 보정(boosts)을 아이템 보정 위에 누적 적용한다.
static func from_slot_with_boosts(slot: RosterSlot, boosts: Dictionary, global_items: Array = []) -> EffectiveStats:
	var s := from_slot(slot, global_items)
	s.attack += float(boosts.get("atk", 0)) * UPGRADE_ATK_VALUE
	s.max_hp += float(boosts.get("hp", 0)) * UPGRADE_HP_VALUE
	s.armor += float(boosts.get("armor", 0)) * UPGRADE_ARMOR_VALUE
	return s

static func from_slot(slot: RosterSlot, global_items: Array = []) -> EffectiveStats:
	var s := EffectiveStats.new()
	var d := slot.unit_data
	s.max_hp = d.max_hp
	s.attack = d.attack
	s.attack_range = d.attack_range * float(GameEnums.CELL_SIZE)
	s.attack_interval = d.attack_interval
	s.move_speed = d.move_speed
	s.armor = d.armor
	for it in slot.items:
		_apply_item(s, it)
	for raw_it in global_items:
		if not (raw_it is ItemData):
			continue
		var it: ItemData = raw_it as ItemData
		var applies := false
		match it.scope:
			ItemData.Scope.ALL_ALLIES: applies = true
			ItemData.Scope.UNIT: applies = (it.condition_unit_id == d.id)
		if applies:
			_apply_item(s, it)
	return s

static func _apply_item(s: EffectiveStats, it: ItemData) -> void:
	match it.stat_key:
		ItemData.StatKey.MOVE_SPEED: s.move_speed += it.value
		ItemData.StatKey.ATTACK:     s.attack     += it.value
		ItemData.StatKey.HP:         s.max_hp     += it.value
		ItemData.StatKey.ARMOR:      s.armor      += it.value

# Enemies carry no items; wraps UnitData in the same interface.
static func from_unit_data(d: UnitData) -> EffectiveStats:
	var s := EffectiveStats.new()
	s.max_hp = d.max_hp
	s.attack = d.attack
	s.attack_range = d.attack_range * float(GameEnums.CELL_SIZE)
	s.attack_interval = d.attack_interval
	s.move_speed = d.move_speed
	s.armor = d.armor
	return s
