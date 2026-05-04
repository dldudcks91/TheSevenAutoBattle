class_name SelectionRing
extends Node2D

@export var radius: float = 18.0
@export var color: Color = Color(1.0, 0.65, 0.2, 0.95)  # 주황색 — 클릭 선택 표시
@export var thickness: float = 2.0

func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, thickness, true)
