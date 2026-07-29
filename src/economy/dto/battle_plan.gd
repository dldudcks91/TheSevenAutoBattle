class_name BattlePlan
extends RefCounted

# PREP → BATTLE 단방향 페이로드 (덱빌딩 모델).
# 배치판은 임시이므로 카드 인스턴스를 그대로 넘긴다 — 전투 후 RunState.recall_after_battle()가 회수한다.

# 각 entry: { "card": Card, "mods": Array[Card], "position": Vector2 }  (1칸 1유닛, 단일 좌표)
var player_units: Array = []

var enemy_lineup: Array = []     # Array[UnitData]
var enemy_positions: Array = []  # Array[Vector2] — battle world coords

var round_index: int = 0
var tactic_key: StringName = &""

# 상시 조커 (전투 이벤트 엔진에서 구독).
var jokers: Array = []           # Array[Joker]
