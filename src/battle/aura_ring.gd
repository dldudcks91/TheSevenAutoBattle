class_name AuraRing
extends Node2D

# 시전자 발 밑에 깔리는 오오라 범위 표시. 단색 반투명 원 + 살짝 진한 테두리.

@export var radius: float = 64.0
@export var fill_color: Color = Color(0.3, 0.6, 1.0, 0.15)
@export var edge_color: Color = Color(0.3, 0.6, 1.0, 0.6)
@export var edge_thickness: float = 2.0
@export var segments: int = 64

func _ready() -> void:
	# 부모(Unit) 자식 중 가장 앞으로 보내 스프라이트보다 먼저 그려지게 한다.
	# (z_index 음수는 FieldFrame 등 형제 노드 아래로 가려지므로 사용하지 않는다.)
	if get_parent() != null:
		get_parent().move_child(self, 0)

func set_radius(r: float) -> void:
	radius = r
	queue_redraw()

func _draw() -> void:
	if radius <= 0.0:
		return
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, segments, edge_color, edge_thickness, true)
