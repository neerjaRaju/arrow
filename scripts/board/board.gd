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

@onready var grid: GridContainer = %Grid

var _board_size := 0
var _arrows: Dictionary = {}
var _buttons: Dictionary = {}
var _input_locked := false


func setup(level_data: Dictionary) -> void:
	_input_locked = false
	for child in grid.get_children():
		child.queue_free()
	_arrows.clear()
	_buttons.clear()
	_board_size = int(level_data.get("size", 4))
	grid.columns = _board_size
	var button_side := floorf(520.0 / _board_size)
	var arrows: Array = level_data.get("arrows", [])
	for arrow: Dictionary in arrows:
		_arrows[arrow["cell"]] = arrow
	for y in _board_size:
		for x in _board_size:
			var cell := Vector2i(x, y)
			var holder := CenterContainer.new()
			holder.custom_minimum_size = Vector2(button_side, button_side)
			grid.add_child(holder)
			var button := Button.new()
			button.custom_minimum_size = Vector2(button_side - 8.0, button_side - 8.0)
			button.focus_mode = Control.FOCUS_NONE
			button.add_theme_font_size_override("font_size", int(button_side * 0.48))
			button.add_theme_color_override("font_color", ACTIVE_COLOR)
			button.add_theme_color_override("font_hover_color", Color.WHITE)
			button.add_theme_color_override("font_pressed_color", Color.WHITE)
			holder.add_child(button)
			_buttons[cell] = button
			if _arrows.has(cell):
				var direction: Vector2i = _arrows[cell]["direction"]
				button.text = ARROW_GLYPHS[direction]
				button.pressed.connect(_on_arrow_pressed.bind(cell))
			else:
				button.hide()


func _on_arrow_pressed(cell: Vector2i) -> void:
	if _input_locked or not _arrows.has(cell):
		return
	var direction: Vector2i = _arrows[cell]["direction"]
	var valid := _path_is_clear(cell, direction)
	arrow_selected.emit(valid)
	var button: Button = _buttons[cell]
	if valid:
		_arrows.erase(cell)
		button.disabled = true
		var travel := Vector2(direction) * 70.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(button, "position", button.position + travel, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(button, "modulate:a", 0.0, 0.16)
		tween.chain().tween_callback(button.hide)
		if _arrows.is_empty():
			_input_locked = true
			get_tree().create_timer(0.22).timeout.connect(board_cleared.emit)
	else:
		button.add_theme_color_override("font_color", BLOCKED_COLOR)
		var original_scale := button.scale
		var tween := create_tween()
		tween.tween_property(button, "scale", original_scale * 0.9, 0.06)
		tween.tween_property(button, "scale", original_scale, 0.09)
		tween.tween_callback(func() -> void: button.add_theme_color_override("font_color", ACTIVE_COLOR))


func _path_is_clear(cell: Vector2i, direction: Vector2i) -> bool:
	var cursor := cell + direction
	while cursor.x >= 0 and cursor.y >= 0 and cursor.x < _board_size and cursor.y < _board_size:
		if _arrows.has(cursor):
			return false
		cursor += direction
	return true
