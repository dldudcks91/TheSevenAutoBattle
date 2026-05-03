class_name ItemData
extends RefCounted

enum StatKey { MOVE_SPEED, ATTACK, HP, ARMOR }
# ALL_ALLIES: 인벤토리에 있는 동안 아군 전체에 적용.
# UNIT: condition_unit_id와 id가 일치하는 유닛에만 적용.
enum Scope { ALL_ALLIES, UNIT }

var id: StringName
var name_key: String
var stat_key: StatKey
var value: float
var price: int
var scope: Scope = Scope.ALL_ALLIES
var condition_unit_id: StringName = &""  # scope == UNIT일 때만 유효

func load_icon() -> Texture2D:
	var path := "res://assets/icons/item_%s.png" % id
	if ResourceLoader.exists(path):
		return load(path)
	return null

static func from_row(row: Dictionary) -> ItemData:
	var it := ItemData.new()
	it.id = StringName(row["id"])
	it.name_key = row["name_key"]
	it.stat_key = StatKey[row["stat_key"]]
	it.value = float(row["value"])
	it.price = int(row["price"])
	it.scope = Scope[row.get("scope", "ALL_ALLIES")]
	it.condition_unit_id = StringName(row.get("condition_unit_id", ""))
	return it
