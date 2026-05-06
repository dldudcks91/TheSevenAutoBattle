extends Node2D

# M2 검증용 1 vs 1 테스트 씬.
# Soldier(좌) vs Orc(우) 자동 전투.

const UNIT_SCENE: PackedScene = preload("res://src/battle/Unit.tscn")
const SOLDIER_DATA: BattleUnitData = preload("res://assets/data/units/allies/soldier.tres")
const ORC_DATA: BattleUnitData = preload("res://assets/data/units/enemies/orc.tres")

const ARENA_Y: float = 420.0
const ALLY_X: float = 400.0
const ENEMY_X: float = 880.0


func _ready() -> void:
	_spawn(SOLDIER_DATA, Vector2(ALLY_X, ARENA_Y))
	_spawn(ORC_DATA, Vector2(ENEMY_X, ARENA_Y))


func _spawn(data: BattleUnitData, pos: Vector2) -> Unit:
	var unit: Unit = UNIT_SCENE.instantiate()
	add_child(unit)
	unit.global_position = pos
	unit.setup(data)
	unit.died.connect(_on_unit_died)
	return unit


func _on_unit_died(unit: Unit) -> void:
	print("[BattleScene] %s (team %d) died" % [unit.data.display_name, unit.team])
