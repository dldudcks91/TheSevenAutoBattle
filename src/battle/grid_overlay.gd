class_name GridOverlay
extends Node2D

@export var cell_size: int = 12
@export var major_every: int = 5
@export var color: Color = Color(0.45, 0.45, 0.5, 0.18)
@export var major_color: Color = Color(0.55, 0.55, 0.65, 0.45)
@export var line_width: float = 1.0
@export var width: int = 1872
@export var height: int = 630

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var cols: int = int(ceil(float(width) / float(cell_size)))
	var rows: int = int(ceil(float(height) / float(cell_size)))
	for c in range(cols + 1):
		var x: float = float(c * cell_size)
		var is_major: bool = major_every > 0 and c % major_every == 0
		draw_line(Vector2(x, 0), Vector2(x, height), major_color if is_major else color, line_width)
	for r in range(rows + 1):
		var y: float = float(r * cell_size)
		var is_major: bool = major_every > 0 and r % major_every == 0
		draw_line(Vector2(0, y), Vector2(width, y), major_color if is_major else color, line_width)
