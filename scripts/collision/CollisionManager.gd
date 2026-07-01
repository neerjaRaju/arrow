class_name CollisionManager
extends Node

## Deterministic grid collision and reservation engine.
##
## The manager is intentionally visual-agnostic. It tracks reserved cells and
## body edges for every snake, then answers whether a head-first move is clear,
## blocked, or exits the board. Gameplay can use the trace result directly to
## drive Snake movement while debug tools render the same reservations.

signal reservations_changed
signal collision_tested(result: Dictionary)

enum CollisionType { NONE, SNAKE, WALL, BOUNDARY, OVERLAP, CROSSING, RESERVED }

const INVALID_CELL := Vector2i(-9999, -9999)
const CARDINAL_DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

@export var board_size := Vector2i(5, 5)
@export var allow_open_boundaries := true

var _snake_cells: Dictionary = {}
var _reservations: Dictionary = {}
var _walls: Dictionary = {}
var _exits: Dictionary = {}
var _edges: Dictionary = {}


func configure(size: Vector2i, walls: Array[Vector2i] = [], exits: Dictionary = {}) -> bool:
	if size.x < GridManager.MIN_BOARD_SIZE or size.y < GridManager.MIN_BOARD_SIZE or size.x > GridManager.MAX_BOARD_SIZE or size.y > GridManager.MAX_BOARD_SIZE:
		push_error("Collision board size %s is outside the supported range." % size)
		return false
	board_size = size
	_walls.clear()
	_exits.clear()
	for wall: Vector2i in walls:
		if contains(wall):
			_walls[_cell_key(wall)] = true
	for key: Variant in exits:
		var direction: Vector2i = exits[key]
		var cell := _as_cell(key)
		set_exit(cell, direction, true)
	_rebuild_reservations()
	return true


func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < board_size.x and cell.y < board_size.y


func reserve_snake(snake_id: StringName, cells_head_to_tail: Array[Vector2i]) -> bool:
	if cells_head_to_tail.is_empty():
		return false
	var unique := {}
	for cell: Vector2i in cells_head_to_tail:
		if not contains(cell):
			return false
		var key := _cell_key(cell)
		if unique.has(key):
			return false
		unique[key] = true
	_snake_cells[snake_id] = cells_head_to_tail.duplicate()
	_rebuild_reservations()
	return true


func release_snake(snake_id: StringName) -> void:
	if not _snake_cells.has(snake_id):
		return
	_snake_cells.erase(snake_id)
	_rebuild_reservations()


func move_reservation(snake_id: StringName, cells_head_to_tail: Array[Vector2i]) -> bool:
	if not reserve_snake(snake_id, cells_head_to_tail):
		_rebuild_reservations()
		return false
	return true


func set_wall(cell: Vector2i, blocked: bool = true) -> void:
	if not contains(cell):
		return
	if blocked:
		_walls[_cell_key(cell)] = true
	else:
		_walls.erase(_cell_key(cell))
	_rebuild_reservations()


func has_wall(cell: Vector2i) -> bool:
	return _walls.has(_cell_key(cell))


func set_exit(cell: Vector2i, direction: Vector2i, enabled: bool = true) -> void:
	if not contains(cell) or not _is_cardinal(direction):
		return
	var key := _exit_key(cell, direction)
	if enabled:
		_exits[key] = true
	else:
		_exits.erase(key)
	reservations_changed.emit()


func has_exit(cell: Vector2i, direction: Vector2i) -> bool:
	return _exits.has(_exit_key(cell, direction)) or (allow_open_boundaries and not contains(cell + direction))


func get_snake_cells(snake_id: StringName) -> Array[Vector2i]:
	return _snake_cells.get(snake_id, []).duplicate()


func get_reserved_cells() -> Dictionary:
	return _reservations.duplicate()


func get_walls() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for key: String in _walls:
		cells.append(_parse_cell_key(key))
	return cells


func get_exits() -> Dictionary:
	return _exits.duplicate()


## Tests a single head-first cell step.
func test_step(snake_id: StringName, direction: Vector2i) -> Dictionary:
	var cells := get_snake_cells(snake_id)
	var result := _evaluate_step(snake_id, cells, direction)
	collision_tested.emit(result)
	return result


## Traces a snake until it reaches an exit or the next step would collide.
func trace_until_blocked(snake_id: StringName, direction: Vector2i, max_steps: int = 128) -> Dictionary:
	var cells := get_snake_cells(snake_id)
	var path: Array[Vector2i] = []
	var last_clear_cells := cells.duplicate()
	if not _is_cardinal(direction) or cells.is_empty():
		return _result(false, CollisionType.RESERVED, "invalid_direction_or_snake", snake_id, INVALID_CELL, "", path, false, last_clear_cells)
	for step in maxi(max_steps, 1):
		var result := _evaluate_step(snake_id, cells, direction)
		if result.get("exit", false):
			result["path"] = path
			result["can_move"] = true
			collision_tested.emit(result)
			return result
		if not bool(result.get("ok", false)):
			result["path"] = path
			result["can_move"] = not path.is_empty()
			result["final_cells"] = last_clear_cells
			collision_tested.emit(result)
			return result
		path.append(result["head_cell"])
		cells = result["final_cells"].duplicate()
		last_clear_cells = cells.duplicate()
	return _result(false, CollisionType.BOUNDARY, "trace_limit", snake_id, INVALID_CELL, "", path, false, last_clear_cells)


func _evaluate_step(snake_id: StringName, cells: Array[Vector2i], direction: Vector2i) -> Dictionary:
	if cells.is_empty() or not _is_cardinal(direction):
		return _result(false, CollisionType.RESERVED, "invalid_move", snake_id, INVALID_CELL, "", [], false, cells)
	var current_head := cells[0]
	var next_head := current_head + direction
	if not contains(next_head):
		if has_exit(current_head, direction):
			return _result(true, CollisionType.NONE, "exit", snake_id, current_head, "", [], true, [])
		return _result(false, CollisionType.BOUNDARY, "boundary", snake_id, current_head, "", [], false, cells)
	if has_wall(next_head):
		return _result(false, CollisionType.WALL, "wall", snake_id, next_head, "wall", [], false, cells)
	var candidate: Array[Vector2i] = [next_head]
	for index in range(0, maxi(cells.size() - 1, 0)):
		candidate.append(cells[index])
	var duplicate_cell := _first_duplicate(candidate)
	if duplicate_cell != INVALID_CELL:
		return _result(false, CollisionType.OVERLAP, "self_overlap", snake_id, duplicate_cell, snake_id, [], false, cells)
	for cell: Vector2i in candidate:
		if has_wall(cell):
			return _result(false, CollisionType.WALL, "wall", snake_id, cell, "wall", [], false, cells)
		var owner := _reservation_owner(cell)
		if owner != "" and owner != String(snake_id):
			return _result(false, CollisionType.SNAKE, "snake", snake_id, cell, owner, [], false, cells)
	if _crosses_reserved_edge(snake_id, current_head, next_head):
		return _result(false, CollisionType.CROSSING, "crossing", snake_id, next_head, "edge", [], false, cells)
	return _result(true, CollisionType.NONE, "clear", snake_id, next_head, "", [], false, candidate)


func _rebuild_reservations() -> void:
	_reservations.clear()
	_edges.clear()
	for key: String in _walls:
		_reservations[key] = "wall"
	for snake_id: StringName in _snake_cells:
		var cells: Array[Vector2i] = _snake_cells[snake_id]
		for cell: Vector2i in cells:
			_reservations[_cell_key(cell)] = String(snake_id)
		for index in cells.size() - 1:
			_edges[_edge_key(cells[index], cells[index + 1])] = String(snake_id)
	reservations_changed.emit()


func _crosses_reserved_edge(snake_id: StringName, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var key := _edge_key(from_cell, to_cell)
	return _edges.has(key) and _edges[key] != String(snake_id)


func _reservation_owner(cell: Vector2i) -> String:
	return String(_reservations.get(_cell_key(cell), ""))


func _first_duplicate(cells: Array[Vector2i]) -> Vector2i:
	var seen := {}
	for cell: Vector2i in cells:
		var key := _cell_key(cell)
		if seen.has(key):
			return cell
		seen[key] = true
	return INVALID_CELL


func _result(ok: bool, collision_type: CollisionType, reason: String, snake_id: StringName, cell: Vector2i, blocker_id: Variant, path: Array[Vector2i], exit: bool, final_cells: Array[Vector2i]) -> Dictionary:
	return {
		"ok": ok,
		"can_move": ok,
		"type": collision_type,
		"reason": reason,
		"snake_id": snake_id,
		"head_cell": cell,
		"blocker_cell": cell,
		"blocker_id": blocker_id,
		"path": path.duplicate(),
		"exit": exit,
		"final_cells": final_cells.duplicate(),
	}


func _is_cardinal(direction: Vector2i) -> bool:
	return CARDINAL_DIRECTIONS.has(direction)


func _as_cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if typeof(value) == TYPE_ARRAY and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return INVALID_CELL


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _parse_cell_key(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(int(parts[0]), int(parts[1])) if parts.size() == 2 else INVALID_CELL


func _edge_key(a: Vector2i, b: Vector2i) -> String:
	var first := _cell_key(a)
	var second := _cell_key(b)
	return "%s|%s" % [first, second] if first < second else "%s|%s" % [second, first]


func _exit_key(cell: Vector2i, direction: Vector2i) -> String:
	return "%s:%d,%d" % [_cell_key(cell), direction.x, direction.y]
