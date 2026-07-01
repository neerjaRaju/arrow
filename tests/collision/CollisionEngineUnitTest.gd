extends Node

var _assertions := 0
var _failed := false


func _ready() -> void:
	var collision := CollisionManager.new()
	add_child(collision)
	_expect(collision.configure(Vector2i(6, 6)), "configure supported board")
	_expect(collision.reserve_snake(&"alpha", [Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2)]), "reserve first snake")
	_expect(collision.reserve_snake(&"beta", [Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3)]), "reserve second snake")
	_expect(not collision.reserve_snake(&"bad", [Vector2i(1, 1), Vector2i(1, 1)]), "reject overlapping body")

	var blocked := collision.test_step(&"alpha", Vector2i.RIGHT)
	_expect(not blocked.ok and blocked.type == CollisionManager.CollisionType.SNAKE, "snake collision detected")

	var clear := collision.test_step(&"alpha", Vector2i.UP)
	_expect(clear.ok and clear.head_cell == Vector2i(2, 1), "clear step detected")
	_expect(collision.move_reservation(&"alpha", clear.final_cells), "cell reservation updates after move")

	collision.set_wall(Vector2i(2, 0), true)
	var wall := collision.test_step(&"alpha", Vector2i.UP)
	_expect(not wall.ok and wall.type == CollisionManager.CollisionType.WALL, "wall collision detected")

	collision.allow_open_boundaries = false
	var boundary := collision.trace_until_blocked(&"alpha", Vector2i.LEFT)
	_expect(boundary.can_move and boundary.type == CollisionManager.CollisionType.BOUNDARY, "boundary blocks after movable path")

	collision.set_exit(Vector2i(0, 1), Vector2i.LEFT, true)
	var exit := collision.trace_until_blocked(&"alpha", Vector2i.LEFT)
	_expect(exit.exit and exit.can_move, "exit detected")

	collision.release_snake(&"beta")
	_expect(not collision.get_reserved_cells().has("3,2"), "release removes reservations")
	collision.free()
	if _failed:
		get_tree().quit(1)
		return
	print("CollisionEngineUnitTest passed %d assertions." % _assertions)
	get_tree().quit(0)


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	_failed = true
	push_error("Collision engine assertion failed: %s" % message)
