class_name FormationDef
extends Resource

# 진형(전술) 정의. 좌표는 EnemyZone 정규화 좌표(0~1 비율).
# Godot 인스펙터에서 편집 가능하도록 Resource로 노출 — 추후 .tres로 추출하기 쉬움.

@export var key: StringName = &""
@export var label_text: String = ""
@export var positions: Array[Vector2] = []
