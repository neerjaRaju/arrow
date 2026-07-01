class_name SnakeTail
extends SnakeBodySegment

## Tapered tail renderer used by [Snake].


func _draw() -> void:
	var tip := Vector2(-radius * 1.28, 0.0)
	var upper := Vector2(radius * 0.72, -radius * 0.62)
	var lower := Vector2(radius * 0.72, radius * 0.62)
	draw_colored_polygon(PackedVector2Array([tip, upper, lower]), fill_color)
	draw_arc(Vector2(radius * 0.16, 0.0), radius * 0.72, -PI * 0.5, PI * 0.5, 18, edge_color, 2.0)
