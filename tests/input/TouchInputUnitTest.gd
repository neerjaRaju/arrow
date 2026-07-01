extends Node

var _assertions := 0
var _failed := false


func _ready() -> void:
	var grid := GridManager.new()
	add_child(grid)
	grid.configure(Vector2i(5, 5), 64.0)
	var controller := TouchInputController.new()
	add_child(controller)
	controller.bind_grid(grid)

	var selected: Array[Vector2i] = []
	var swipes: Array[Vector2i] = []
	controller.selection_requested.connect(func(cell: Vector2i) -> void: selected.append(cell))
	controller.swipe.connect(func(_cell: Vector2i, direction: Vector2i, _velocity: float) -> void: swipes.append(direction))

	_send_touch(controller, 0, grid.grid_to_world(Vector2i(2, 2)), true)
	_send_touch(controller, 0, grid.grid_to_world(Vector2i(2, 2)), false)
	_expect(selected.size() == 1 and selected[0] == Vector2i(2, 2), "tap selects grid cell")

	_send_touch(controller, 0, grid.grid_to_world(Vector2i(1, 1)), true)
	_send_touch(controller, 1, grid.grid_to_world(Vector2i(4, 4)), true)
	_send_touch(controller, 1, grid.grid_to_world(Vector2i(4, 4)), false)
	_send_touch(controller, 0, grid.grid_to_world(Vector2i(4, 1)), false)
	_expect(swipes.size() == 1 and swipes[0] == Vector2i.RIGHT, "single-touch swipe recognized and multitouch ignored")

	controller.set_input_enabled(false)
	_send_touch(controller, 0, grid.grid_to_world(Vector2i(3, 3)), true)
	_send_touch(controller, 0, grid.grid_to_world(Vector2i(3, 3)), false)
	_expect(controller.buffered_count() == 1, "tap buffered while locked")
	controller.set_input_enabled(true)
	_expect(controller.buffered_count() == 0 and selected[-1] == Vector2i(3, 3), "buffer flushes on unlock")

	controller.free()
	grid.free()
	if _failed:
		get_tree().quit(1)
		return
	print("TouchInputUnitTest passed %d assertions." % _assertions)
	get_tree().quit(0)


func _send_touch(controller: TouchInputController, index: int, world_position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = controller.get_viewport().get_canvas_transform() * world_position
	event.pressed = pressed
	controller._unhandled_input(event)


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	_failed = true
	push_error("Touch input assertion failed: %s" % message)
