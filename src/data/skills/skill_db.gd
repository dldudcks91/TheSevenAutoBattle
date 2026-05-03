extends Node
# Autoload — skills.csv를 읽어 SkillData 인스턴스로 보관.

const CSV_PATH := "res://src/data/skills/skills.csv"

var _by_id: Dictionary = {}

func _ready() -> void:
	var rows := CsvLoader.load_table(CSV_PATH)
	for r in rows:
		var s := SkillData.from_row(r)
		_by_id[s.id] = s
	print("[SkillDB] loaded ", _by_id.size(), " skills")

func get_by_id(id: StringName) -> SkillData:
	return _by_id.get(id)

func has(id: StringName) -> bool:
	return _by_id.has(id)
