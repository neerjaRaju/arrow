class_name SnakeBodySegment
extends Node2D

## Visual body piece used by [Snake].
##
## Segments are deliberately state-light so they can be pooled aggressively.
## The snake engine owns path sampling; each segment only draws its current
## capsule-like body piece and eases scale/rotation toward supplied values.

const DEFAULT_COLOR := Color("6ee7d8")
const EDGE_COLOR := Color("9ff8ee")

@export var radius := 28.0:
	set(value):
		radius = maxf(value, 2.0)
		queue_redraw()
@export var fill_color := DEFAULT_COLOR:
	set(value):
		fill_color = value
		queue_redraw()
@export var edge_color := EDGE_COLOR:
	set(value):
		edge_color = value
		queue_redraw()

var segment_index := 0
var target_scale := Vector2.ONE
var rotation_smoothing := 18.0
var scale_smoothing := 18.0


func configure(index: int, visual_radius: float, color: Color, edge: Color = EDGE_COLOR) -> void:
	segment_index = index
	radius = visual_radius
	fill_color = color
	edge_color = edge
	queue_redraw()


func apply_pose(target_position: Vector2, target_rotation: float, delta: float, scale_multiplier: float = 1.0) -> void:
	position = target_position
	rotation = lerp_angle(rotation, target_rotation, 1.0 - exp(-rotation_smoothing * delta))
	target_scale = Vector2.ONE * scale_multiplier
	scale = scale.lerp(target_scale, 1.0 - exp(-scale_smoothing * delta))


func snap_pose(target_position: Vector2, target_rotation: float, scale_multiplier: float = 1.0) -> void:
	position = target_position
	rotation = target_rotation
	scale = Vector2.ONE * scale_multiplier


func _draw() -> void:
	var body_rect := Rect2(Vector2(-radius * 0.9, -radius * 0.72), Vector2(radius * 1.8, radius * 1.44))
	draw_circle(Vector2.ZERO, radius * 0.78, fill_color)
	draw_rect(body_rect, fill_color, true)
	draw_circle(Vector2(-radius * 0.9, 0.0), radius * 0.72, fill_color)
	draw_circle(Vector2(radius * 0.9, 0.0), radius * 0.72, fill_color)
	draw_arc(Vector2.ZERO, radius * 0.86, 0.0, TAU, 28, edge_color, 2.0)
