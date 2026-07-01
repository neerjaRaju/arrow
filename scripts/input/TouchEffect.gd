class_name TouchEffect
extends Node2D

## Pooled touch ripple drawn without textures.

const DEFAULT_COLOR := Color("6ee7d8")

var _radius := 0.0
var _alpha := 0.0
var _color := DEFAULT_COLOR


func play(world_position: Vector2, color: Color = DEFAULT_COLOR, max_radius: float = 54.0, duration: float = 0.28) -> void:
	position = world_position
	_color = color
	_radius = 8.0
	_alpha = 0.75
	show()
	queue_redraw()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "_radius", max_radius, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_alpha", 0.0, duration)
	tween.chain().tween_callback(hide)


func _set(property: StringName, value: Variant) -> bool:
	if property == &"_radius":
		_radius = float(value)
		queue_redraw()
		return true
	if property == &"_alpha":
		_alpha = float(value)
		queue_redraw()
		return true
	return false


func _draw() -> void:
	if _alpha <= 0.0:
		return
	var color := Color(_color.r, _color.g, _color.b, _alpha)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 36, color, 4.0)
	draw_circle(Vector2.ZERO, _radius * 0.18, Color(_color.r, _color.g, _color.b, _alpha * 0.55))
