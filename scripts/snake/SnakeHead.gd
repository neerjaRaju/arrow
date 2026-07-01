class_name SnakeHead
extends Node2D

## Head renderer and smoothed orientation controller for [Snake].

const DEFAULT_COLOR := Color("6ee7d8")
const FACE_COLOR := Color("07101c")
const EYE_COLOR := Color("ecfffb")

@export var radius := 31.0:
	set(value):
		radius = maxf(value, 2.0)
		queue_redraw()
@export var fill_color := DEFAULT_COLOR:
	set(value):
		fill_color = value
		queue_redraw()
@export var rotation_smoothing := 20.0

var _target_rotation := 0.0


func configure(visual_radius: float, color: Color) -> void:
	radius = visual_radius
	fill_color = color
	queue_redraw()


func apply_pose(target_position: Vector2, direction: Vector2, delta: float, snap: bool = false) -> void:
	position = target_position
	if direction.length_squared() > 0.0001:
		_target_rotation = direction.angle()
	rotation = _target_rotation if snap else lerp_angle(rotation, _target_rotation, 1.0 - exp(-rotation_smoothing * delta))


func _draw() -> void:
	var nose := Vector2(radius * 1.08, 0.0)
	var upper := Vector2(-radius * 0.76, -radius * 0.72)
	var lower := Vector2(-radius * 0.76, radius * 0.72)
	draw_colored_polygon(PackedVector2Array([nose, upper, lower]), fill_color)
	draw_circle(Vector2(-radius * 0.28, 0.0), radius * 0.82, fill_color)
	draw_arc(Vector2(-radius * 0.18, 0.0), radius * 0.9, -PI * 0.82, PI * 0.82, 24, Color("9ff8ee"), 2.0)
	draw_circle(Vector2(radius * 0.16, -radius * 0.28), radius * 0.13, EYE_COLOR)
	draw_circle(Vector2(radius * 0.16, radius * 0.28), radius * 0.13, EYE_COLOR)
	draw_circle(Vector2(radius * 0.2, -radius * 0.28), radius * 0.055, FACE_COLOR)
	draw_circle(Vector2(radius * 0.2, radius * 0.28), radius * 0.055, FACE_COLOR)
