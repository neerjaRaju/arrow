class_name Snake
extends Node2D

## Catmull-Rom spline snake engine.
##
## The head advances along recorded points first. Body and tail pieces then
## sample the same history at fixed spacing behind the head. This avoids rigid
## grid-snapping, teleporting, or segment-by-segment popping while still keeping
## the logical snake path available to collision and puzzle systems.

signal movement_started(snake: Snake, path: Array[Vector2i])
signal movement_finished(snake: Snake, path: Array[Vector2i])
signal path_updated(snake: Snake)

enum MotionState { IDLE, MOVING }

const BODY_SEGMENT_SCENE := preload("res://scenes/snake/SnakeBodySegment.tscn")
const DEFAULT_SNAKE_COLOR := Color("6ee7d8")
const MIN_VISUAL_LENGTH := 2

@export_range(2, 32, 1) var visual_length := 5:
	set(value):
		visual_length = maxi(value, MIN_VISUAL_LENGTH)
		_sync_segment_count()
		_apply_pose(0.0, true)
@export_range(0.05, 0.5, 0.01) var move_seconds_per_cell := 0.16
@export_range(2, 18, 1) var curve_samples_per_cell := 8
@export_range(0.0, 18.0, 0.25) var zig_zag_amplitude := 4.0
@export_range(0.0, 4.0, 0.05) var zig_zag_frequency := 1.15
@export_range(4.0, 40.0, 0.5) var rotation_smoothing := 18.0
@export var snake_color := DEFAULT_SNAKE_COLOR:
	set(value):
		snake_color = value
		_apply_colors()

@onready var body_root: Node2D = %BodyRoot
@onready var tail: SnakeTail = %SnakeTail
@onready var head: SnakeHead = %SnakeHead
@onready var animation_tree: AnimationTree = %AnimationTree

var snake_id := &"snake"
var grid_cells: Array[Vector2i] = []
var head_cell := Vector2i.ZERO
var tail_cell := Vector2i.ZERO
var cell_size := 72.0
var segment_spacing := 52.0
var motion_state := MotionState.IDLE

var _control_points: Array[Vector2] = []
var _sample_points: Array[Vector2] = []
var _sample_distances := PackedFloat32Array()
var _active_segments: Array[SnakeBodySegment] = []
var _segment_pool: Array[SnakeBodySegment] = []
var _last_move_path: Array[Vector2i] = []
var _head_distance := 0.0
var _start_distance := 0.0
var _target_distance := 0.0
var _move_elapsed := 0.0
var _move_duration := 0.0


func _ready() -> void:
	animation_tree.active = true
	_apply_colors()
	_sync_segment_count()
	_apply_pose(0.0, true)


func _process(delta: float) -> void:
	if motion_state == MotionState.MOVING:
		_move_elapsed += delta
		var progress := clampf(_move_elapsed / maxf(_move_duration, 0.001), 0.0, 1.0)
		var eased := smoothstep(0.0, 1.0, progress)
		_head_distance = lerpf(_start_distance, _target_distance, eased)
		_apply_pose(delta, false)
		if progress >= 1.0:
			motion_state = MotionState.IDLE
			_head_distance = _target_distance
			_apply_pose(delta, false)
			movement_finished.emit(self, _last_move_path.duplicate())
	else:
		_apply_pose(delta, false)


func _exit_tree() -> void:
	for segment: SnakeBodySegment in _segment_pool:
		segment.free()
	_segment_pool.clear()


## Configures the snake from grid cells ordered head-to-tail.
func configure_from_grid(new_id: StringName, cells_head_to_tail: Array[Vector2i], grid: GridManager, color: Color = DEFAULT_SNAKE_COLOR) -> void:
	position = grid.position
	var local_points: Array[Vector2] = []
	for cell: Vector2i in cells_head_to_tail:
		local_points.append(grid.grid_to_local_position(cell))
	configure_from_points(new_id, cells_head_to_tail, local_points, grid.cell_size, color)


## Configures the snake from logical cells and matching local points ordered head-to-tail.
func configure_from_points(new_id: StringName, cells_head_to_tail: Array[Vector2i], points_head_to_tail: Array[Vector2], new_cell_size: float, color: Color = DEFAULT_SNAKE_COLOR) -> void:
	if points_head_to_tail.is_empty():
		return
	snake_id = new_id
	cell_size = maxf(new_cell_size, 1.0)
	segment_spacing = cell_size * 0.72
	snake_color = color
	grid_cells = cells_head_to_tail.duplicate()
	head_cell = grid_cells[0] if not grid_cells.is_empty() else Vector2i.ZERO
	tail_cell = grid_cells[-1] if not grid_cells.is_empty() else head_cell
	visual_length = maxi(points_head_to_tail.size(), MIN_VISUAL_LENGTH)
	_control_points.clear()
	for index in range(points_head_to_tail.size() - 1, -1, -1):
		_control_points.append(points_head_to_tail[index])
	_rebuild_samples()
	_head_distance = _total_distance()
	_start_distance = _head_distance
	_target_distance = _head_distance
	_apply_pose(0.0, true)
	path_updated.emit(self)


## Moves the head through cells ordered from the next cell through the final cell.
func move_along_grid(next_cells: Array[Vector2i], grid: GridManager) -> bool:
	if next_cells.is_empty() or motion_state == MotionState.MOVING:
		return false
	var local_points: Array[Vector2] = []
	for cell: Vector2i in next_cells:
		local_points.append(grid.grid_to_local_position(cell))
	return move_along_points(next_cells, local_points, grid.cell_size)


## Moves the head through points ordered from next point through final point.
func move_along_points(next_cells: Array[Vector2i], next_points: Array[Vector2], travel_cell_size: float = 72.0) -> bool:
	if next_points.is_empty() or motion_state == MotionState.MOVING:
		return false
	_last_move_path = next_cells.duplicate()
	_start_distance = _head_distance
	for point: Vector2 in next_points:
		if _control_points.is_empty() or _control_points[-1].distance_squared_to(point) > 0.01:
			_control_points.append(point)
	_rebuild_samples()
	_target_distance = _total_distance()
	var travel_distance := maxf(_target_distance - _start_distance, 1.0)
	_move_duration = maxf(move_seconds_per_cell * travel_distance / maxf(travel_cell_size, 1.0), 0.04)
	_move_elapsed = 0.0
	motion_state = MotionState.MOVING
	if not next_cells.is_empty():
		head_cell = next_cells[-1]
		_update_logical_body(next_cells)
	movement_started.emit(self, next_cells.duplicate())
	return true


func set_visual_length(piece_count: int) -> void:
	visual_length = maxi(piece_count, MIN_VISUAL_LENGTH)


func is_moving() -> bool:
	return motion_state == MotionState.MOVING


func get_recorded_head_path() -> Array[Vector2]:
	return _control_points.duplicate()


func get_head_position() -> Vector2:
	return head.position


func get_tail_position() -> Vector2:
	return tail.position


func sample_position(distance_behind_head: float, include_zig_zag: bool = false) -> Vector2:
	var distance := clampf(_head_distance - maxf(distance_behind_head, 0.0), 0.0, _total_distance())
	var base := _sample_at_distance(distance)
	if not include_zig_zag:
		return base
	return base + _zig_zag_offset(distance)


func _sync_segment_count() -> void:
	if not is_inside_tree() or body_root == null:
		return
	var desired_body_count := maxi(visual_length - 2, 0)
	while _active_segments.size() < desired_body_count:
		var segment := _take_segment()
		body_root.add_child(segment)
		_active_segments.append(segment)
	while _active_segments.size() > desired_body_count:
		var segment: SnakeBodySegment = _active_segments.pop_back()
		segment.hide()
		segment.get_parent().remove_child(segment)
		_segment_pool.append(segment)
	_apply_colors()


func _take_segment() -> SnakeBodySegment:
	if not _segment_pool.is_empty():
		var segment: SnakeBodySegment = _segment_pool.pop_back()
		segment.show()
		return segment
	var segment: SnakeBodySegment = BODY_SEGMENT_SCENE.instantiate()
	return segment


func _apply_colors() -> void:
	if not is_inside_tree():
		return
	var edge := snake_color.lightened(0.35)
	if head != null:
		head.configure(cell_size * 0.42, snake_color)
	if tail != null:
		tail.configure(visual_length - 1, cell_size * 0.32, snake_color.darkened(0.08), edge)
	for index in _active_segments.size():
		var depth := float(index + 1) / float(maxi(_active_segments.size() + 1, 1))
		_active_segments[index].configure(index, cell_size * lerpf(0.37, 0.31, depth), snake_color.lerp(snake_color.darkened(0.12), depth), edge)


func _apply_pose(delta: float, snap: bool = false) -> void:
	if _sample_points.is_empty() or head == null:
		return
	var head_position := sample_position(0.0, motion_state == MotionState.MOVING)
	var head_direction := _tangent_at_distance(_head_distance)
	head.apply_pose(head_position, head_direction, delta, snap)
	for index in _active_segments.size():
		var distance_behind := segment_spacing * float(index + 1)
		var position_at_segment := sample_position(distance_behind, motion_state == MotionState.MOVING)
		var angle := _tangent_at_distance(_head_distance - distance_behind).angle()
		var pulse := 1.0 + sin((_head_distance / maxf(cell_size, 1.0) + float(index) * 0.45) * TAU) * 0.025
		if snap:
			_active_segments[index].snap_pose(position_at_segment, angle, pulse)
		else:
			_active_segments[index].apply_pose(position_at_segment, angle, delta, pulse)
	var tail_distance := segment_spacing * float(maxi(visual_length - 1, 1))
	var tail_position := sample_position(tail_distance, false)
	var tail_angle := _tangent_at_distance(_head_distance - tail_distance).angle()
	if tail != null:
		tail.visible = visual_length > 1
		if snap:
			tail.snap_pose(tail_position, tail_angle)
		else:
			tail.apply_pose(tail_position, tail_angle, delta)


func _update_logical_body(next_cells: Array[Vector2i]) -> void:
	if grid_cells.is_empty():
		grid_cells = next_cells.duplicate()
	else:
		for cell: Vector2i in next_cells:
			grid_cells.insert(0, cell)
	while grid_cells.size() > visual_length:
		grid_cells.pop_back()
	head_cell = grid_cells[0]
	tail_cell = grid_cells[-1]


func _rebuild_samples() -> void:
	_sample_points.clear()
	_sample_distances.clear()
	if _control_points.is_empty():
		return
	if _control_points.size() == 1:
		_sample_points.append(_control_points[0])
		_sample_distances.append(0.0)
		return
	var last_point := _control_points[0]
	var distance := 0.0
	_sample_points.append(last_point)
	_sample_distances.append(distance)
	for index in _control_points.size() - 1:
		var p0 := _control_points[maxi(index - 1, 0)]
		var p1 := _control_points[index]
		var p2 := _control_points[index + 1]
		var p3 := _control_points[mini(index + 2, _control_points.size() - 1)]
		for sample_index in range(1, curve_samples_per_cell + 1):
			var t := float(sample_index) / float(curve_samples_per_cell)
			var point := _catmull_rom(p0, p1, p2, p3, t)
			distance += last_point.distance_to(point)
			_sample_points.append(point)
			_sample_distances.append(distance)
			last_point = point


func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


func _sample_at_distance(distance: float) -> Vector2:
	if _sample_points.is_empty():
		return Vector2.ZERO
	var clamped := clampf(distance, 0.0, _total_distance())
	var low := 0
	var high := _sample_distances.size() - 1
	while low < high:
		var middle := (low + high) / 2
		if _sample_distances[middle] < clamped:
			low = middle + 1
		else:
			high = middle
	var upper := maxi(low, 1)
	var lower := upper - 1
	var start_distance := _sample_distances[lower]
	var end_distance := _sample_distances[upper]
	var weight := 0.0 if is_equal_approx(start_distance, end_distance) else (clamped - start_distance) / (end_distance - start_distance)
	return _sample_points[lower].lerp(_sample_points[upper], weight)


func _tangent_at_distance(distance: float) -> Vector2:
	var before := _sample_at_distance(distance - 2.0)
	var after := _sample_at_distance(distance + 2.0)
	var tangent := after - before
	return tangent.normalized() if tangent.length_squared() > 0.0001 else Vector2.RIGHT


func _zig_zag_offset(distance: float) -> Vector2:
	if zig_zag_amplitude <= 0.0:
		return Vector2.ZERO
	var tangent := _tangent_at_distance(distance)
	var normal := Vector2(-tangent.y, tangent.x)
	var time_phase := float(Time.get_ticks_msec()) * 0.006
	var wave := sin((distance / maxf(cell_size, 1.0)) * TAU * zig_zag_frequency + time_phase) * zig_zag_amplitude
	return normal * wave


func _total_distance() -> float:
	return _sample_distances[-1] if not _sample_distances.is_empty() else 0.0
