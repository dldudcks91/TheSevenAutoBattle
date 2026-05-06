class_name RosterStore
extends RefCounted

# 핸드/로스터/인벤토리 + 핸드 롤 로직을 책임진다.
# 골드 결제는 Economy를 호출자가 합성해서 처리한다(여기는 카드만 다룸).

var roster: Array[RosterSlot] = []
var hand: Array[RosterSlot] = []
var inventory: Array[ItemData] = []
var rng := RandomNumberGenerator.new()

func clear() -> void:
	roster.clear()
	hand.clear()
	inventory.clear()

func roll_hand(pool: Array[UnitData], hand_offer_count: int, grid_units: Array[UnitData] = []) -> void:
	hand.clear()
	if pool.is_empty():
		return
	for _i in hand_offer_count:
		hand.append(_roll_hand_offer(pool, grid_units))

# 카드 풀 가중치 — SKILL 카드 폐지 후 3종(HERO/UPGRADE/ITEM)으로 단순화.
# 누적 임계값 형태로 사용.
const _HERO_THRESHOLD: float = 0.60
const _UPGRADE_THRESHOLD: float = 0.77  # HERO 60% + UPGRADE 17%

func _roll_hand_offer(pool: Array[UnitData], grid_units: Array[UnitData]) -> RosterSlot:
	# UPGRADE: 스탯 지정 강화 (그리드에 유닛 있을 때만 — 그렇지 않으면 HERO로 폴백).
	var roll: float = rng.randf()
	var slot := RosterSlot.new()
	var has_grid := not grid_units.is_empty()
	if roll < _HERO_THRESHOLD or (not has_grid and roll < _UPGRADE_THRESHOLD):
		slot.kind = GameEnums.CardKind.HERO
		slot.unit_data = pool[rng.randi_range(0, pool.size() - 1)]
	elif roll < _UPGRADE_THRESHOLD:
		if has_grid:
			slot.kind = GameEnums.CardKind.UPGRADE
			var stats := ["atk", "hp", "defense"]
			slot.upgrade_stat = stats[rng.randi_range(0, stats.size() - 1)]
			slot.dummy_name = _upgrade_name(slot.upgrade_stat)
			slot.dummy_desc = _upgrade_desc(slot.upgrade_stat)
			slot.dummy_price = 8
		else:
			slot.kind = GameEnums.CardKind.HERO
			slot.unit_data = pool[rng.randi_range(0, pool.size() - 1)]
	else:
		slot.kind = GameEnums.CardKind.ITEM
		var offers := ItemDB.random_offers(rng, 1)
		if not offers.is_empty():
			var it: ItemData = offers[0]
			slot.item_data = it
			slot.dummy_name = TranslationServer.translate(it.name_key)
			slot.dummy_price = it.price
		else:
			slot.dummy_name = "???"
			slot.dummy_price = 5
	return slot

func _upgrade_name(stat: String) -> String:
	match stat:
		"atk":   return TranslationServer.translate(&"UPGRADE_ATK")
		"hp":    return TranslationServer.translate(&"UPGRADE_HP")
		"defense": return TranslationServer.translate(&"UPGRADE_DEFENSE")
	return TranslationServer.translate(&"UPGRADE_ATK")

func _upgrade_desc(stat: String) -> String:
	match stat:
		"atk":   return TranslationServer.translate(&"UPGRADE_ATK_DESC")
		"hp":    return TranslationServer.translate(&"UPGRADE_HP_DESC")
		"defense": return TranslationServer.translate(&"UPGRADE_DEFENSE_DESC")
	return ""

func _skill_name(ud: UnitData) -> String:
	if String(ud.default_skill_id).is_empty():
		return TranslationServer.translate(ud.name_key)
	var sd: SkillData = SkillDB.get_by_id(ud.default_skill_id)
	if sd != null:
		return TranslationServer.translate(sd.name_key)
	return TranslationServer.translate(ud.name_key)

func _skill_desc(ud: UnitData) -> String:
	if String(ud.default_skill_id).is_empty():
		return ""
	var sd: SkillData = SkillDB.get_by_id(ud.default_skill_id)
	if sd != null:
		return TranslationServer.translate(sd.desc_key)
	return ""

func equip_item(slot_idx: int, inventory_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= roster.size():
		return false
	if inventory_idx < 0 or inventory_idx >= inventory.size():
		return false
	var slot: RosterSlot = roster[slot_idx]
	if not slot.can_equip():
		return false
	var it: ItemData = inventory[inventory_idx]
	inventory.remove_at(inventory_idx)
	slot.equip(it)
	return true

func unequip_item(slot_idx: int, item_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= roster.size():
		return false
	var it: ItemData = roster[slot_idx].unequip(item_idx)
	if it == null:
		return false
	inventory.append(it)
	return true
