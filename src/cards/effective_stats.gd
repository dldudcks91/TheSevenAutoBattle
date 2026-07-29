class_name EffectiveStats
extends RefCounted

# Computed battle stats for a spawned unit. UnitData stays read-only baseline;
# items attached at the RosterSlot (type) level are summed here once per slot
# and shared by every instance of that type spawned in a battle.

# 업그레이드 카드 1회 적용 시 더해지는 스탯 양.
const UPGRADE_ATK_VALUE: float = 10.0
const UPGRADE_HP_VALUE: float = 50.0
const UPGRADE_DEFENSE_VALUE: float = 2.0

var max_hp: float
var attack: float
var attack_range: float
var attack_speed: float
var move_speed: float
var defense: float

# 셀 업그레이드 보정(boosts)을 아이템 보정 위에 누적 적용한다.
static func from_slot_with_boosts(slot: RosterSlot, boosts: Dictionary, global_items: Array = []) -> EffectiveStats:
	var s := from_slot(slot, global_items)
	s.attack += float(boosts.get("atk", 0)) * UPGRADE_ATK_VALUE
	s.max_hp += float(boosts.get("hp", 0)) * UPGRADE_HP_VALUE
	s.defense += float(boosts.get("defense", 0)) * UPGRADE_DEFENSE_VALUE
	return s

static func from_slot(slot: RosterSlot, global_items: Array = []) -> EffectiveStats:
	var s := EffectiveStats.new()
	var d := slot.unit_data
	s.max_hp = d.max_hp
	s.attack = d.attack
	s.attack_range = d.attack_range * float(GameEnums.CELL_SIZE)
	s.attack_speed = d.attack_speed
	s.move_speed = d.move_speed
	s.defense = d.defense
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
		ItemData.StatKey.DEFENSE:    s.defense    += it.value

# 덱빌딩 모델 — 병사 카드 + 부착된 시한부 강화(mods)로 전투 스탯 산출.
# 강화는 그 전투에만 유효하며 전투 후 카드째 회수된다 (개별 유닛 영구 누적 없음).
static func from_card_with_mods(card: Card, mods: Array) -> EffectiveStats:
	var s := from_unit_data(card.unit_data)
	for m in mods:
		var mc := m as Card
		if mc == null:
			continue
		match String(mc.mod_stat):
			"atk":          s.attack += mc.mod_amount
			"hp":           s.max_hp += mc.mod_amount
			"defense":      s.defense += mc.mod_amount
			"attack_speed": s.attack_speed += mc.mod_amount
			"move_speed":   s.move_speed += mc.mod_amount
		# 키워드형 강화(mod_keyword)는 최소 구현에서 스탯 무영향 — 후속 확장(다단히트·흡혈 등).
	return s

# Enemies carry no items; wraps UnitData in the same interface.
static func from_unit_data(d: UnitData) -> EffectiveStats:
	var s := EffectiveStats.new()
	s.max_hp = d.max_hp
	s.attack = d.attack
	s.attack_range = d.attack_range * float(GameEnums.CELL_SIZE)
	s.attack_speed = d.attack_speed
	s.move_speed = d.move_speed
	s.defense = d.defense
	return s
