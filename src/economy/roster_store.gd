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
	# SKILL 카드는 같은 핸드에 영웅 카드가 있을 때만 유효하므로 2차 패스에서 확정.
	_resolve_skill_cards(pool)

func _roll_hand_offer(pool: Array[UnitData], grid_units: Array[UnitData]) -> RosterSlot:
	# UPGRADE: 스탯 지정 강화 (그리드에 유닛 있을 때만).
	# SKILL: 2차 패스에서 핸드 영웅 기반으로 확정 — 여기선 종류만 예약.
	var roll: float = rng.randf()
	var slot := RosterSlot.new()
	var has_grid := not grid_units.is_empty()
	if roll < 0.6 or (not has_grid and roll < 0.87):
		slot.kind = GameEnums.CardKind.HERO
		slot.unit_data = pool[rng.randi_range(0, pool.size() - 1)]
	elif roll < 0.74:
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
	elif roll < 0.87:
		if has_grid:
			# unit_data / dummy_name 은 _resolve_skill_cards 에서 채운다.
			slot.kind = GameEnums.CardKind.SKILL
			slot.dummy_price = 6
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

# SKILL 카드를 같은 핸드에 나온 영웅 중 스킬 보유 영웅과 연결한다.
# 해당하는 영웅이 없으면 HERO 카드로 전환.
func _resolve_skill_cards(pool: Array[UnitData]) -> void:
	var hand_heroes_with_skills: Array[UnitData] = []
	for slot: RosterSlot in hand:
		if slot.kind == GameEnums.CardKind.HERO and slot.unit_data != null:
			if not String(slot.unit_data.default_skill_id).is_empty():
				hand_heroes_with_skills.append(slot.unit_data)

	for slot: RosterSlot in hand:
		if slot.kind != GameEnums.CardKind.SKILL:
			continue
		if hand_heroes_with_skills.is_empty():
			slot.kind = GameEnums.CardKind.HERO
			slot.unit_data = pool[rng.randi_range(0, pool.size() - 1)]
		else:
			var picked: UnitData = hand_heroes_with_skills[rng.randi_range(0, hand_heroes_with_skills.size() - 1)]
			slot.unit_data = picked
			slot.dummy_name = _skill_name(picked)
			slot.dummy_desc = _skill_desc(picked)

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
