extends Control

@onready var grid: GridManager = %GridManager
@onready var collision: CollisionManager = %CollisionManager
@onready var debugger: CollisionDebugger = %CollisionDebugger
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	collision.configure(Vector2i(7, 7))
	collision.allow_open_boundaries = false
	collision.set_exit(Vector2i(6, 2), Vector2i.RIGHT, true)
	collision.set_wall(Vector2i(3, 3), true)
	collision.reserve_snake(&"alpha", [Vector2i(1, 2), Vector2i(0, 2)])
	collision.reserve_snake(&"beta", [Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4)])
	debugger.bind(grid, collision)
	status_label.text = "Collision Debugger • reservations, wall, exit, and tested path"
	var result := collision.trace_until_blocked(&"alpha", Vector2i.RIGHT)
	debugger.set_last_result(result)
