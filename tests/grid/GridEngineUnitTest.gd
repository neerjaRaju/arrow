extends Node

@onready var grid: GridManager = %GridManager

var _assertions := 0


func _ready() -> void:
	_run_tests()
	print("GridEngineUnitTest passed %d assertions." % _assertions)
	get_tree().quit(0)


func _run_tests() -> void:
	for side in range(GridManager.MIN_BOARD_SIZE, GridManager.MAX_BOARD_SIZE + 1):
		_expect(grid.configure(Vector2i(side, side), 48.0), "Configure %dx%d" % [side, side])
		_expect(grid.board_size == Vector2i(side, side), "Configured dimensions")
		_expect(grid.occupied_count() == 0, "Fresh occupancy is empty")

		var samples: Array[Vector2i] = [Vector2i.ZERO, Vector2i(side / 2, side / 2), Vector2i(side - 1, side - 1)]
		for cell in samples:
			var local_center := grid.grid_to_local_position(cell)
			_expect(grid.local_to_grid(local_center) == cell, "Local conversion round trip")
			var world_center := grid.grid_to_world(cell)
			_expect(grid.world_to_grid(world_center) == cell, "World conversion round trip")

	var target := Vector2i(8, 7)
	var occupant := {
		"id": 42,
		"kind": &"arrow",
		"direction": Vector2i.LEFT,
		"tint": Color("6ee7d8"),
		"metadata": [true, 3.5, "grid"],
	}
	_expect(grid.configure(Vector2i(10, 10), 52.0), "Configure maximum grid")
	_expect(grid.set_occupant(target, occupant), "Set occupant")
	_expect(grid.is_occupied(target), "Occupancy lookup")
	_expect(grid.get_occupant(target)["id"] == 42, "Occupant payload lookup")
	_expect(grid.occupied_count() == 1, "Occupancy count")
	_expect(grid.highlight_cell(target), "Highlight valid cell")
	_expect(grid.highlighted_cell == target, "Highlight state")
	_expect(grid.select_cell(target, false), "Select valid cell")
	_expect(grid.selected_cell == target, "Selection state")

	var serialized := grid.serialize_grid()
	var json_round_trip: Variant = JSON.parse_string(JSON.stringify(serialized))
	_expect(typeof(json_round_trip) == TYPE_DICTIONARY, "Snapshot is JSON-safe")
	_expect(grid.configure(Vector2i(5, 5), 32.0), "Mutate before restore")
	_expect(grid.deserialize_grid(json_round_trip), "Deserialize snapshot")
	_expect(grid.board_size == Vector2i(10, 10), "Restored dimensions")
	_expect(is_equal_approx(grid.cell_size, 52.0), "Restored cell size")
	_expect(grid.selected_cell == target, "Restored selection")
	var restored: Dictionary = grid.get_occupant(target)
	_expect(restored["direction"] == Vector2i.LEFT, "Restored Vector2i")
	_expect(restored["kind"] == &"arrow", "Restored StringName")
	_expect(restored["tint"].is_equal_approx(Color("6ee7d8")), "Restored Color")

	grid.position = Vector2(30, 40)
	var touch_cell := Vector2i(2, 3)
	var touch := InputEventScreenTouch.new()
	touch.position = grid.grid_to_world(touch_cell)
	touch.pressed = true
	grid._unhandled_input(touch)
	_expect(grid.selected_cell == touch_cell, "Touch selects converted cell")
	_expect(grid.clear_occupant(target) != null, "Clear returns occupant")
	_expect(not grid.is_occupied(target), "Clear removes occupancy")
	_expect(grid.clear_occupant(target) == null, "Clearing empty cell is stable")


func _expect(condition: bool, label: String) -> void:
	_assertions += 1
	assert(condition, "Grid assertion failed: %s" % label)
