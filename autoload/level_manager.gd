extends Node

const MIN_BOARD_SIZE := 5
const MAX_BOARD_SIZE := 10
const LEVELS_PER_SIZE := 8
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


func get_level(level_number: int) -> Dictionary:
	var safe_level: int = maxi(level_number, 1)
	var size_increase: int = floori(float(safe_level - 1) / float(LEVELS_PER_SIZE))
	var board_size: int = clampi(MIN_BOARD_SIZE + size_increase, MIN_BOARD_SIZE, MAX_BOARD_SIZE)
	var center: Vector2 = Vector2((board_size - 1) * 0.5, (board_size - 1) * 0.5)
	var cells: Array[Vector2i] = []
	for y in board_size:
		for x in board_size:
			cells.append(Vector2i(x, y))

	# Center-out placement guarantees a solution in reverse: every arrow points
	# through cells that are placed later, so the outermost legal arrow can leave.
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_distance := Vector2(a).distance_squared_to(center)
		var b_distance := Vector2(b).distance_squared_to(center)
		if is_equal_approx(a_distance, b_distance):
			return _stable_cell_key(a, safe_level, board_size) < _stable_cell_key(b, safe_level, board_size)
		return a_distance < b_distance
	)

	var arrows: Array[Dictionary] = []
	for index in cells.size():
		var cell: Vector2i = cells[index]
		var direction: Vector2i = _outward_direction(cell, center, safe_level + index)
		arrows.append({
			"id": index,
			"cell": cell,
			"direction": direction,
		})
	return {
		"number": safe_level,
		"size": board_size,
		"arrows": arrows,
		"par_moves": arrows.size(),
	}


func _outward_direction(cell: Vector2i, center: Vector2, seed: int) -> Vector2i:
	var offset := Vector2(cell) - center
	var direction: Vector2i
	if absf(offset.x) > absf(offset.y):
		direction = Vector2i.RIGHT if offset.x > 0.0 else Vector2i.LEFT
	elif absf(offset.y) > absf(offset.x):
		direction = Vector2i.DOWN if offset.y > 0.0 else Vector2i.UP
	else:
		if is_zero_approx(offset.x) and is_zero_approx(offset.y):
			direction = DIRECTIONS[posmod(seed, DIRECTIONS.size())]
		elif posmod(seed, 2) == 0:
			direction = Vector2i.RIGHT if offset.x > 0.0 else Vector2i.LEFT
		else:
			direction = Vector2i.DOWN if offset.y > 0.0 else Vector2i.UP
	return direction


func _stable_cell_key(cell: Vector2i, level_number: int, board_size: int) -> int:
	return posmod(cell.x * 73856093 ^ cell.y * 19349663 ^ level_number * 83492791, board_size * board_size * 17)
