class_name Economy
extends RefCounted

# 골드와 밸런스 상수, 결제/환불을 책임진다.
# RunState facade가 이 인스턴스를 보유하고 외부에 위임한다.

var STARTING_GOLD: int = 30
var REWARD_PER_ROUND: int = 22
var REWARD_GROWTH_PER_ROUND: int = 2
var HIRE_PRICE_PER_COST: int = 5
var REROLL_COST: int = 3
var SHOP_ITEM_OFFER_COUNT: int = 3
var HAND_OFFER_COUNT: int = 5

var gold: int = 0

func load_balance() -> void:
	var rows := CsvLoader.load_table("res://src/data/balance.csv")
	for row in rows:
		match row["key"]:
			"starting_gold":            STARTING_GOLD = int(row["value"])
			"reward_per_round":         REWARD_PER_ROUND = int(row["value"])
			"reward_growth_per_round":  REWARD_GROWTH_PER_ROUND = int(row["value"])
			"hire_price_per_cost":      HIRE_PRICE_PER_COST = int(row["value"])
			"reroll_cost":              REROLL_COST = int(row["value"])
			"shop_item_offer_count":    SHOP_ITEM_OFFER_COUNT = int(row["value"])
			"hand_offer_count":         HAND_OFFER_COUNT = int(row["value"])

func can_afford(amount: int) -> bool:
	return gold >= amount

func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	gold -= amount
	return true

func refund(amount: int) -> void:
	gold += amount

func buy_item(it: ItemData, inventory: Array[ItemData]) -> bool:
	if not spend(it.price):
		return false
	inventory.append(it)
	return true

func hire_price_for(unit: UnitData) -> int:
	return unit.cost * HIRE_PRICE_PER_COST
