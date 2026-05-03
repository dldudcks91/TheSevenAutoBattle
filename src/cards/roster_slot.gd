class_name RosterSlot
extends RefCounted

# A roster slot represents a unit TYPE the player can hire each battle.
# Soldiers are not "owned" — they are bought fresh each BattlePrep. The slot's
# only persistent role is being the home for items attached to this type.
# Every soldier hired of this type benefits from the slot's items in battle.

const MAX_ITEMS := 3

var unit_data: UnitData
var items: Array[ItemData] = []
# 핸드 슬롯의 카드 종류. 그리드용 영웅(HERO)과 더미 카드(UPGRADE/SKILL/ITEM)를 구분.
var kind: int = GameEnums.CardKind.HERO
# 더미 카드 가격(HERO 외만 사용). HERO는 RunState.hire_price_for() 사용.
var dummy_price: int = 0
# 더미 카드 표시명(HERO 외만 사용).
var dummy_name: String = ""
# 더미 카드 설명(HERO 외만 사용).
var dummy_desc: String = ""
# ITEM 카드일 때만 유효 — CSV에서 로드한 실제 아이템 데이터.
var item_data: ItemData = null
# UPGRADE 카드일 때만 유효 — 강화할 스탯 키 ("atk" / "hp" / "armor").
var upgrade_stat: String = ""

func can_equip() -> bool:
	return items.size() < MAX_ITEMS

func equip(it: ItemData) -> bool:
	if not can_equip():
		return false
	items.append(it)
	return true

func unequip(idx: int) -> ItemData:
	if idx < 0 or idx >= items.size():
		return null
	return items.pop_at(idx)
