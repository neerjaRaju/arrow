class_name TouchInputController
extends Node

## Android-optimized single-touch controller.
##
## One controller handles tap, drag, swipe, selection, deselection, buffering,
## and touch effects. It intentionally avoids per-cell Control input so the
## board can remain cheap on 10x10 levels.

signal tap(cell: Vector2i, world_position: Vector2)
signal drag_started(cell: Vector2i, world_position: Vector2)
signal drag_updated(cell: Vector2i, world_position: Vector2, delta: Vector2)
signal drag_finished(cell: Vector2i, world_position: Vector2)
signal swipe(cell: Vector2i, direction: Vector2i, velocity: float)
signal selection_requested(cell: Vector2i)
signal deselect_requested
signal input_buffered(gesture: Dictionary)

const TOUCH_EFFECT_SCENE := preload("res://scenes/input/TouchEffect.tscn")
const INVALID_TOUCH := -1
const INVALID_CELL := Vector2i(-1, -1)
const BUFFER_LIMIT := 8

@export var grid_manager_path: NodePath
@export var effect_layer_path: NodePath
@export var multi_touch_enabled := false
@export var tap_max_duration := 0.24
@export var tap_max_distance := 22.0
@export var swipe_min_distance := 42.0
@export var swipe_min_velocity := 280.0
@export var buffer_window_seconds := 0.32
@export var input_enabled := true:
	set(value):
		input_enabled = value
		if input_enabled:
			_flush_buffered_gestures()

var selected_cell := INVALID_CELL

var _grid: GridManager
var _effect_layer: Node2D
var _active_touch := INVALID_TOUCH
var _touch_started := false
var _dragging := false
var _start_viewport := Vector2.ZERO
var _last_viewport := Vector2.ZERO
var _start_world := Vector2.ZERO
var _start_cell := INVALID_CELL
var _start_time_msec := 0
var _buffer: Array[Dictionary] = []
var _effect_pool: Array[TouchEffect] = []


func _ready() -> void:
	_grid = get_node_or_null(grid_manager_path) as GridManager
	_effect_layer = get_node_or_null(effect_layer_path) as Node2D


func bind_grid(grid: GridManager, effect_layer: Node2D = null) -> void:
	_grid = grid
	if effect_layer != null:
		_effect_layer = effect_layer


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled


func clear_selection() -> void:
	if selected_cell == INVALID_CELL:
		return
	selected_cell = INVALID_CELL
	deselect_requested.emit()


func buffered_count() -> int:
	return _buffer.size()


func consume_buffered_gestures() -> Array[Dictionary]:
	var gestures := _buffer.duplicate(true)
	_buffer.clear()
	return gestures


func _unhandled_input(event: InputEvent) -> void:
	if _grid == null:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_drag(event.index, event.position, event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_touch(0, event.position, event.pressed)
	elif event is InputEventMouseMotion and _touch_started:
		_handle_drag(0, event.position, event.relative)


func _handle_touch(index: int, viewport_position: Vector2, pressed: bool) -> void:
	if pressed:
		if not multi_touch_enabled and _active_touch != INVALID_TOUCH:
			return
		_active_touch = index
		_touch_started = true
		_dragging = false
		_start_viewport = viewport_position
		_last_viewport = viewport_position
		_start_world = _viewport_to_world(viewport_position)
		_start_cell = _grid.world_to_grid(_start_world)
		_start_time_msec = Time.get_ticks_msec()
		return
	if index != _active_touch:
		return
	var world_position := _viewport_to_world(viewport_position)
	var end_cell := _grid.world_to_grid(world_position)
	var duration := float(Time.get_ticks_msec() - _start_time_msec) / 1000.0
	var travel := viewport_position - _start_viewport
	var distance := travel.length()
	var velocity := distance / maxf(duration, 0.001)
	if distance <= tap_max_distance and duration <= tap_max_duration:
		_dispatch_or_buffer({
			"type": &"tap",
			"cell": end_cell,
			"world_position": world_position,
			"time": Time.get_ticks_msec(),
		})
	else:
		var direction := _direction_from_vector(travel)
		if distance >= swipe_min_distance and velocity >= swipe_min_velocity and direction != Vector2i.ZERO:
			_dispatch_or_buffer({
				"type": &"swipe",
				"cell": _start_cell,
				"world_position": world_position,
				"direction": direction,
				"velocity": velocity,
				"time": Time.get_ticks_msec(),
			})
		_dispatch_or_buffer({
			"type": &"drag_finished",
			"cell": end_cell,
			"world_position": world_position,
			"time": Time.get_ticks_msec(),
		})
	_active_touch = INVALID_TOUCH
	_touch_started = false
	_dragging = false


func _handle_drag(index: int, viewport_position: Vector2, relative: Vector2) -> void:
	if index != _active_touch:
		return
	var world_position := _viewport_to_world(viewport_position)
	var cell := _grid.world_to_grid(world_position)
	if not _dragging and viewport_position.distance_to(_start_viewport) > tap_max_distance:
		_dragging = true
		_dispatch_or_buffer({
			"type": &"drag_started",
			"cell": _start_cell,
			"world_position": _start_world,
			"time": Time.get_ticks_msec(),
		})
	if _dragging:
		_dispatch_or_buffer({
			"type": &"drag_updated",
			"cell": cell,
			"world_position": world_position,
			"delta": relative,
			"time": Time.get_ticks_msec(),
		})
	_last_viewport = viewport_position


func _dispatch_or_buffer(gesture: Dictionary) -> void:
	if not input_enabled:
		_buffer.append(gesture.duplicate(true))
		while _buffer.size() > BUFFER_LIMIT:
			_buffer.pop_front()
		input_buffered.emit(gesture.duplicate(true))
		return
	_dispatch_gesture(gesture)


func _flush_buffered_gestures() -> void:
	if _buffer.is_empty():
		return
	var now := Time.get_ticks_msec()
	var gestures := consume_buffered_gestures()
	for gesture: Dictionary in gestures:
		var age := float(now - int(gesture.get("time", now))) / 1000.0
		if age <= buffer_window_seconds:
			_dispatch_gesture(gesture)


func _dispatch_gesture(gesture: Dictionary) -> void:
	var world_position: Vector2 = gesture.get("world_position", Vector2.ZERO)
	var cell: Vector2i = gesture.get("cell", INVALID_CELL)
	_play_touch_effect(world_position)
	match gesture.get("type", &""):
		&"tap":
			tap.emit(cell, world_position)
			if _grid.contains(cell):
				selected_cell = cell
				selection_requested.emit(cell)
			else:
				clear_selection()
		&"drag_started":
			drag_started.emit(cell, world_position)
		&"drag_updated":
			drag_updated.emit(cell, world_position, gesture.get("delta", Vector2.ZERO))
		&"drag_finished":
			drag_finished.emit(cell, world_position)
		&"swipe":
			swipe.emit(cell, gesture.get("direction", Vector2i.ZERO), float(gesture.get("velocity", 0.0)))


func _viewport_to_world(viewport_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * viewport_position


func _direction_from_vector(vector: Vector2) -> Vector2i:
	if vector.length_squared() <= 0.001:
		return Vector2i.ZERO
	if absf(vector.x) >= absf(vector.y):
		return Vector2i.RIGHT if vector.x > 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if vector.y > 0.0 else Vector2i.UP


func _play_touch_effect(world_position: Vector2) -> void:
	if _effect_layer == null:
		return
	var effect := _take_effect()
	if effect.get_parent() != _effect_layer:
		_effect_layer.add_child(effect)
	effect.play(_effect_layer.to_local(world_position), Color("6ee7d8"))


func _take_effect() -> TouchEffect:
	for effect: TouchEffect in _effect_pool:
		if not effect.visible:
			return effect
	var effect: TouchEffect = TOUCH_EFFECT_SCENE.instantiate()
	_effect_pool.append(effect)
	return effect
