extends Node

const SNAKE_SCENE := preload("res://scenes/snake/Snake.tscn")

var _assertions := 0


func _ready() -> void:
	_test_configuration_and_pooling()
	_test_spline_motion_without_teleport()
	print("SnakeEngineUnitTest passed %d assertions." % _assertions)
	get_tree().quit(0)


func _test_configuration_and_pooling() -> void:
	var snake: Snake = SNAKE_SCENE.instantiate()
	add_child(snake)
	var cells: Array[Vector2i] = [Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2)]
	var points: Array[Vector2] = []
	for cell: Vector2i in cells:
		points.append(Vector2(cell) * 72.0 + Vector2.ONE * 36.0)
	snake.configure_from_points(&"test", cells, points, 72.0, Color("6ee7d8"))
	_expect(snake.visual_length == 5, "visual length mirrors configured cells")
	_expect(snake.grid_cells.size() == 5, "logical cells stored")
	_expect(snake.get_child_count() >= 4, "scene contains body, head, tail, and animation nodes")
	var initial_pool_size := snake.get_recorded_head_path().size()
	_expect(initial_pool_size == 5, "head path stores tail-to-head points")
	snake.set_visual_length(8)
	_expect(snake.visual_length == 8, "length can increase")
	snake.set_visual_length(3)
	_expect(snake.visual_length == 3, "length can shrink and pool inactive segments")
	snake.animation_tree.active = false
	snake.free()


func _test_spline_motion_without_teleport() -> void:
	var snake: Snake = SNAKE_SCENE.instantiate()
	add_child(snake)
	var cells: Array[Vector2i] = [Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2)]
	var points: Array[Vector2] = [Vector2(180, 180), Vector2(108, 180), Vector2(36, 180)]
	snake.configure_from_points(&"curve", cells, points, 72.0, Color("ffcc66"))
	var start_position := snake.get_head_position()
	var next_cells: Array[Vector2i] = [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 2)]
	var next_points: Array[Vector2] = [Vector2(180, 108), Vector2(252, 108), Vector2(324, 180)]
	_expect(snake.move_along_points(next_cells, next_points, 72.0), "movement starts")
	_expect(snake.is_moving(), "snake reports moving")
	for index in 12:
		snake._process(0.04)
	var mid_position := snake.get_head_position()
	_expect(mid_position.distance_to(start_position) > 1.0, "head advances smoothly")
	_expect(mid_position.distance_to(next_points[-1]) > 1.0, "head does not teleport to target")
	for index in 18:
		snake._process(0.05)
	_expect(not snake.is_moving(), "movement finishes")
	_expect(snake.head_cell == Vector2i(4, 2), "logical head reaches target")
	_expect(snake.get_head_position().distance_to(next_points[-1]) < 12.0, "visual head reaches final point")
	snake.animation_tree.active = false
	snake.free()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	push_error("Snake engine assertion failed: %s" % message)
	get_tree().quit(1)
