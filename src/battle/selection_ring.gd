class_name SelectionRing
extends Node2D

@export var radius: float = 24.0
@export var color: Color = Color(0.3, 1.0, 0.4, 0.9)
@export var thickness: float = 2.0

func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, thickness, true)
