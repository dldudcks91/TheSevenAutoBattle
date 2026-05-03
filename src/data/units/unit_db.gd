extends Node

const CSV_PATH := "res://src/data/units/units.csv"

var _by_id: Dictionary = {}
var _all: Array[UnitData] = []

func _ready() -> void:
	var rows := CsvLoader.load_table(CSV_PATH)
	for r in rows:
		var u := UnitData.from_row(r)
		_by_id[u.id] = u
		_all.append(u)
	print("[UnitDB] loaded ", _all.size(), " units")

func all() -> Array[UnitData]:
	return _all

func all_player_units() -> Array[UnitData]:
	return _all.filter(func(u: UnitData) -> bool: return u.is_player)

func get_by_id(id: StringName) -> UnitData:
	return _by_id.get(id)
