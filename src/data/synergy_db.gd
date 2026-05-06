extends Node

# synergies.csv 로드 + 조회 헬퍼. autoload(SynergyDB)로 등록.

const CSV_PATH := "res://src/data/synergies.csv"

var _all: Array[SynergyDef] = []
var _by_id: Dictionary = {}
# { SynergyType.CLASS: { Class.KNIGHT: SynergyDef, ... }, SynergyType.RACE: { ... } }
var _by_type_key: Dictionary = {}

func _ready() -> void:
	var rows := CsvLoader.load_table(CSV_PATH)
	for r in rows:
		var d := SynergyDef.from_row(r)
		_all.append(d)
		_by_id[d.id] = d
		if not _by_type_key.has(d.type):
			_by_type_key[d.type] = {}
		(_by_type_key[d.type] as Dictionary)[d.type_key] = d
	print("[SynergyDB] loaded ", _all.size(), " synergies")

func all() -> Array[SynergyDef]:
	return _all

func get_by_id(id: StringName) -> SynergyDef:
	return _by_id.get(id)

func get_by_type_key(type: GameEnums.SynergyType, type_key: int) -> SynergyDef:
	var sub: Dictionary = _by_type_key.get(type, {})
	return sub.get(type_key)
