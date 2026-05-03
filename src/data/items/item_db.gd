extends Node

const CSV_PATH := "res://src/data/items/items.csv"

var _by_id: Dictionary = {}
var _all: Array[ItemData] = []

func _ready() -> void:
	var rows := CsvLoader.load_table(CSV_PATH)
	for r in rows:
		var it := ItemData.from_row(r)
		_by_id[it.id] = it
		_all.append(it)
	print("[ItemDB] loaded ", _all.size(), " items")

func all() -> Array[ItemData]:
	return _all

func get_by_id(id: StringName) -> ItemData:
	return _by_id.get(id)

func random_offers(rng: RandomNumberGenerator, n: int) -> Array[ItemData]:
	var out: Array[ItemData] = []
	if _all.is_empty():
		return out
	for i in n:
		out.append(_all[rng.randi_range(0, _all.size() - 1)])
	return out
