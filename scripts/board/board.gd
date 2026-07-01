extends Control

signal arrow_selected(valid: bool)
signal board_cleared

const ARROW_GLYPHS := {
	Vector2i.UP: "↑",
	Vector2i.RIGHT: "→",
	Vector2i.DOWN: "↓",
	Vector2i.LEFT: "←",
}
const ACTIVE_COLOR := Color("6ee7d8")
const BLOCKED_COLOR := Color("ff7285")

@onready var grid_surface: Control = %GridSurface
@onready var grid_manager: GridManager = %GridManager
@onready var touch_input: TouchInputController = %TouchInputController

var _board_size := 0
var _arrows: Dictionary = {}
var _input_locked := false


func setup(level_data: Dictionary) -> void:
	_input_locked = false
	_arrows.clear()
	_board_size = clampi(int(level_data.get("size", 5)), GridManager.MIN_BOARD_SIZE, GridManager.MAX_BOARD_SIZE)
	var cell_side := floorf(540.0 / float(_board_size))
	grid_manager.touch_enabled = false
	touch_input.set_input_enabled(true)
	grid_manager.configure(Vector2i(_board_size, _board_size), cell_side)
	_layout_grid()
	var arrows: Array = level_data.get("arrows", [])
	for arrow: Dictionary in arrows:
		_arrows[arrow["cell"]] = arrow
		grid_manager.set_occupant(arrow["cell"], arrow)
		var cell_node := grid_manager.get_cell_node(arrow["cell"])
		cell_node.set_content(ARROW_GLYPHS[arrow["direction"]], ACTIVE_COLOR)


func _ready() -> void:
	touch_input.bind_grid(grid_manager, %TouchEffects)
	touch_input.selection_requested.connect(_on_cell_selected)
	grid_surface.resized.connect(_layout_grid)


func _layout_grid() -> void:
	if not is_instance_valid(grid_manager):
		return
	var pixel_size := Vector2(grid_manager.board_size) * grid_manager.cell_size
	grid_manager.position = (grid_surface.size - pixel_size) * 0.5


func _on_cell_selected(cell: Vector2i) -> void:
	if _input_locked or not grid_manager.is_occupied(cell):
		return
	_on_arrow_pressed(cell)


func _on_arrow_pressed(cell: Vector2i) -> void:
	if _input_locked or not _arrows.has(cell):
		return
	var direction: Vector2i = _arrows[cell]["direction"]
	var valid := _path_is_clear(cell, direction)
	arrow_selected.emit(valid)
	var cell_node := grid_manager.get_cell_node(cell)
	if valid:
		_arrows.erase(cell)
		grid_manager.clear_occupant(cell)
		touch_input.set_input_enabled(not _arrows.is_empty())
		var travel := Vector2(direction) * grid_manager.cell_size
		var tween := create_tween().set_parallel(true)
		tween.tween_property(cell_node, "position", cell_node.position + travel, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(cell_node, "modulate:a", 0.0, 0.16)
		tween.chain().tween_callback(func() -> void:
			cell_node.set_content("")
			cell_node.hide()
		)
		if _arrows.is_empty():
			_input_locked = true
			get_tree().create_timer(0.22).timeout.connect(board_cleared.emit)
	else:
		cell_node.flash(BLOCKED_COLOR)


func _path_is_clear(cell: Vector2i, direction: Vector2i) -> bool:
	var cursor := cell + direction
	while cursor.x >= 0 and cursor.y >= 0 and cursor.x < _board_size and cursor.y < _board_size:
		if grid_manager.is_occupied(cursor):
			return false
		cursor += direction
	return true
