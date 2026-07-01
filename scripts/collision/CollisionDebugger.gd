class_name CollisionDebugger
extends Node2D

## Lightweight renderer for collision reservations and the latest collision.

const RESERVED_COLOR := Color(1.0, 0.45, 0.53, 0.28)
const WALL_COLOR := Color(0.18, 0.21, 0.29, 0.82)
const EXIT_COLOR := Color(0.43, 0.91, 0.85, 0.82)
const BLOCKER_COLOR := Color(1.0, 0.2, 0.32, 0.95)
const PATH_COLOR := Color(1.0, 0.8, 0.4, 0.5)

@export var enabled := true:
	set(value):
		enabled = value
		queue_redraw()

var grid: GridManager
var collision_manager: CollisionManager
var last_result: Dictionary = {}


func bind(new_grid: GridManager, new_collision_manager: CollisionManager) -> void:
	grid = new_grid
	collision_manager = new_collision_manager
	if not collision_manager.reservations_changed.is_connected(queue_redraw):
		collision_manager.reservations_changed.connect(queue_redraw)
	if not collision_manager.collision_tested.is_connected(set_last_result):
		collision_manager.collision_tested.connect(set_last_result)
	queue_redraw()


func set_last_result(result: Dictionary) -> void:
	last_result = result.duplicate(true)
	queue_redraw()


func _draw() -> void:
	if not enabled or grid == null or collision_manager == null:
		return
	var inset := grid.cell_size * 0.13
	for wall: Vector2i in collision_manager.get_walls():
		_draw_cell(wall, WALL_COLOR, inset)
	for key: String in collision_manager.get_reserved_cells():
		var cell := _parse_cell_key(key)
		if collision_manager.has_wall(cell):
			continue
		_draw_cell(cell, RESERVED_COLOR, inset)
	for exit_key: String in collision_manager.get_exits():
		var cell := _parse_cell_key(exit_key.get_slice(":", 0))
		_draw_cell(cell, EXIT_COLOR, grid.cell_size * 0.28)
	var path: Array = last_result.get("path", [])
	for cell: Vector2i in path:
		_draw_cell(cell, PATH_COLOR, grid.cell_size * 0.24)
	if last_result.has("blocker_cell") and last_result.get("type", CollisionManager.CollisionType.NONE) != CollisionManager.CollisionType.NONE:
		_draw_cell(last_result["blocker_cell"], BLOCKER_COLOR, grid.cell_size * 0.08)


func _draw_cell(cell: Vector2i, color: Color, inset: float) -> void:
	if not grid.contains(cell):
		return
	var top_left := grid.position + grid.grid_to_local_position(cell, false) + Vector2.ONE * inset
	var size := Vector2.ONE * (grid.cell_size - inset * 2.0)
	draw_rect(Rect2(top_left, size), color, true)


func _parse_cell_key(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(int(parts[0]), int(parts[1])) if parts.size() == 2 else CollisionManager.INVALID_CELL
