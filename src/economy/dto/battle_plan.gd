class_name BattlePlan
extends RefCounted

# PREP → BATTLE 단방향 페이로드.
# RunState mutable 필드 경유 대신 명시적 객체로 데이터 흐름을 표현한다.

# Each entry: { "slot": RosterSlot, "positions": Array[Vector2] }
var player_units: Array = []

var enemy_lineup: Array = []     # Array[UnitData]
var enemy_positions: Array = []  # Array[Vector2] — battle world coords

var round_index: int = 0
var tactic_key: StringName = &""
var global_items: Array = []  # Array[ItemData] — 인벤토리 복사본. ALL_ALLIES/UNIT 스코프 적용용.
