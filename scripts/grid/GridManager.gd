class_name GridManager
extends Node2D

## Production grid engine for rectangular 5x5 through 10x10 boards.
##
## Occupancy uses a flat row-major array for constant-time lookup without
## Vector2i dictionary hashing. Coordinate conversion is local-transform aware,
## so the grid may be translated, scaled, or placed below a CanvasLayer.

signal grid_configured(size: Vector2i, cell_size: float)
signal occupancy_changed(cell: Vector2i, occupant: Variant)
signal cell_selected(cell: Vector2i)
signal selection_changed(previous: Vector2i, current: Vector2i)

const MIN_BOARD_SIZE := 5
const MAX_BOARD_SIZE := 10
const SERIALIZATION_VERSION := 1
const INVALID_CELL := Vector2i(-1, -1)
const CELL_SCENE := preload("res://scenes/grid/GridCell.tscn")

@export_range(5, 10, 1) var initial_columns := 5
@export_range(5, 10, 1) var initial_rows := 5
@export_range(24.0, 128.0, 1.0) var initial_cell_size := 64.0
@export var touch_enabled := true
@export var debug_grid_drawing := false:
	set(value):
		debug_grid_drawing = value
		_apply_debug_state_to_cells()
		queue_redraw()

var board_size := Vector2i(5, 5)
var cell_size := 64.0
var selected_cell := INVALID_CELL
var highlighted_cell := INVALID_CELL

var _occupancy: Array = []
var _cells: Array[GridCell] = []


func _ready() -> void:
	configure(Vector2i(initial_columns, initial_rows), initial_cell_size)


## Rebuilds the grid and clears occupancy. Returns false for unsupported sizes.
## Reconfiguration is intentionally explicit because it invalidates occupants.
func configure(size: Vector2i, size_in_pixels: float = 64.0) -> bool:
	if not _size_is_supported(size):
		push_error("Grid size %s is outside the supported 5x5–10x10 range." % size)
		return false
	if size_in_pixels <= 0.0:
		push_error("Grid cell size must be greater than zero.")
		return false

	_clear_cells()
	board_size = size
	cell_size = size_in_pixels
	_occupancy.resize(board_size.x * board_size.y)
	_occupancy.fill(null)
	selected_cell = INVALID_CELL
	highlighted_cell = INVALID_CELL

	for y in board_size.y:
		for x in board_size.x:
			var cell: GridCell = CELL_SCENE.instantiate()
			add_child(cell)
			cell.configure(Vector2i(x, y), cell_size)
			_cells.append(cell)
	_apply_debug_state_to_cells()
	queue_redraw()
	grid_configured.emit(board_size, cell_size)
	return true


## Returns true when the coordinate is inside the configured board.
func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < board_size.x and cell.y < board_size.y


## Converts a grid coordinate to this node's local coordinate space.
func grid_to_local_position(cell: Vector2i, centered: bool = true) -> Vector2:
	var result := Vector2(cell) * cell_size
	if centered:
		result += Vector2.ONE * cell_size * 0.5
	return result


## Converts a grid coordinate to canvas/world coordinates.
func grid_to_world(cell: Vector2i, centered: bool = true) -> Vector2:
	return to_global(grid_to_local_position(cell, centered))


## Converts local coordinates to a cell, or INVALID_CELL when out of bounds.
func local_to_grid(local_position: Vector2) -> Vector2i:
	var cell := Vector2i(floori(local_position.x / cell_size), floori(local_position.y / cell_size))
	return cell if contains(cell) else INVALID_CELL


## Converts canvas/world coordinates to a cell, respecting this node's transform.
func world_to_grid(world_position: Vector2) -> Vector2i:
	return local_to_grid(to_local(world_position))


## Assigns serializable occupant data in O(1). Null means empty and is rejected.
func set_occupant(cell: Vector2i, occupant: Variant) -> bool:
	if not contains(cell) or occupant == null:
		return false
	var index := _index(cell)
	_occupancy[index] = occupant
	_cells[index].set_occupied(true)
	occupancy_changed.emit(cell, occupant)
	return true


## Clears and returns the previous occupant, or null for an invalid/empty cell.
func clear_occupant(cell: Vector2i) -> Variant:
	if not contains(cell):
		return null
	var index := _index(cell)
	var previous: Variant = _occupancy[index]
	if previous == null:
		return null
	_occupancy[index] = null
	_cells[index].set_occupied(false)
	occupancy_changed.emit(cell, null)
	return previous


## Returns occupant data without copying it.
func get_occupant(cell: Vector2i) -> Variant:
	return _occupancy[_index(cell)] if contains(cell) else null


func is_occupied(cell: Vector2i) -> bool:
	return contains(cell) and _occupancy[_index(cell)] != null


func occupied_count() -> int:
	var count := 0
	for occupant: Variant in _occupancy:
		if occupant != null:
			count += 1
	return count


## Exposes the visual cell for feature-specific content or animation.
func get_cell_node(cell: Vector2i) -> GridCell:
	return _cells[_index(cell)] if contains(cell) else null


## Selects one cell and optionally emits selection signals.
func select_cell(cell: Vector2i, emit_signals: bool = true) -> bool:
	if not contains(cell):
		return false
	var previous := selected_cell
	if contains(previous):
		_cells[_index(previous)].set_selected(false)
	selected_cell = cell
	_cells[_index(cell)].set_selected(true)
	if emit_signals:
		selection_changed.emit(previous, selected_cell)
		cell_selected.emit(selected_cell)
	return true


## Highlights one cell, clearing the previous highlight.
func highlight_cell(cell: Vector2i) -> bool:
	if contains(highlighted_cell):
		_cells[_index(highlighted_cell)].set_highlighted(false)
	highlighted_cell = INVALID_CELL
	if not contains(cell):
		return false
	highlighted_cell = cell
	_cells[_index(cell)].set_highlighted(true)
	return true


func clear_highlight() -> void:
	highlight_cell(INVALID_CELL)


## Produces a JSON-safe, versioned snapshot of layout, selection, and occupancy.
## Occupants may contain primitives, arrays, dictionaries, Vector2/Vector2i,
## Color, and StringName values. Objects and other engine resources are rejected.
func serialize_grid() -> Dictionary:
	var entries: Array[Dictionary] = []
	for index in _occupancy.size():
		if _occupancy[index] == null:
			continue
		entries.append({
			"cell": [_cells[index].coordinate.x, _cells[index].coordinate.y],
			"occupant": _encode_variant(_occupancy[index]),
		})
	return {
		"version": SERIALIZATION_VERSION,
		"size": [board_size.x, board_size.y],
		"cell_size": cell_size,
		"selected": [selected_cell.x, selected_cell.y] if contains(selected_cell) else null,
		"occupancy": entries,
	}


## Restores a snapshot created by serialize_grid. Invalid data is rejected
## without partially mutating the current grid.
func deserialize_grid(snapshot: Dictionary) -> bool:
	if int(snapshot.get("version", -1)) != SERIALIZATION_VERSION:
		return false
	var size_data: Variant = snapshot.get("size")
	if typeof(size_data) != TYPE_ARRAY or size_data.size() != 2:
		return false
	var restored_size := Vector2i(int(size_data[0]), int(size_data[1]))
	if not _size_is_supported(restored_size):
		return false
	var restored_cell_size := float(snapshot.get("cell_size", 0.0))
	if restored_cell_size <= 0.0:
		return false
	var entries: Variant = snapshot.get("occupancy", [])
	if typeof(entries) != TYPE_ARRAY:
		return false
	for entry: Variant in entries:
		if typeof(entry) != TYPE_DICTIONARY or not _serialized_cell_is_valid(entry.get("cell"), restored_size):
			return false

	configure(restored_size, restored_cell_size)
	for entry: Dictionary in entries:
		var position_data: Array = entry["cell"]
		set_occupant(Vector2i(int(position_data[0]), int(position_data[1])), _decode_variant(entry.get("occupant")))
	var selected_data: Variant = snapshot.get("selected")
	if _serialized_cell_is_valid(selected_data, restored_size):
		select_cell(Vector2i(int(selected_data[0]), int(selected_data[1])), false)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not touch_enabled:
		return
	var viewport_position := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch:
		viewport_position = event.position
		pressed = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		viewport_position = event.position
		pressed = event.pressed
	if not pressed:
		return
	var world_position := get_viewport().get_canvas_transform().affine_inverse() * viewport_position
	var cell := world_to_grid(world_position)
	if select_cell(cell):
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if not debug_grid_drawing:
		return
	var bounds := Rect2(Vector2.ZERO, Vector2(board_size) * cell_size)
	draw_rect(bounds, Color("ffcc66"), false, 2.0)


func _index(cell: Vector2i) -> int:
	return cell.y * board_size.x + cell.x


func _size_is_supported(size: Vector2i) -> bool:
	return size.x >= MIN_BOARD_SIZE and size.y >= MIN_BOARD_SIZE and size.x <= MAX_BOARD_SIZE and size.y <= MAX_BOARD_SIZE


func _clear_cells() -> void:
	for cell: GridCell in _cells:
		cell.free()
	_cells.clear()
	_occupancy.clear()


func _apply_debug_state_to_cells() -> void:
	for cell: GridCell in _cells:
		cell.set_debug_label_visible(debug_grid_drawing)


func _serialized_cell_is_valid(value: Variant, size: Vector2i) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() != 2:
		return false
	var cell := Vector2i(int(value[0]), int(value[1]))
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func _encode_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return {"__grid_type": "StringName", "value": String(value)}
		TYPE_VECTOR2I:
			return {"__grid_type": "Vector2i", "x": value.x, "y": value.y}
		TYPE_VECTOR2:
			return {"__grid_type": "Vector2", "x": value.x, "y": value.y}
		TYPE_COLOR:
			return {"__grid_type": "Color", "value": value.to_html(true)}
		TYPE_ARRAY:
			var encoded_array: Array = []
			for item: Variant in value:
				encoded_array.append(_encode_variant(item))
			return encoded_array
		TYPE_DICTIONARY:
			var encoded_dictionary: Dictionary = {}
			for key: Variant in value:
				encoded_dictionary[String(key)] = _encode_variant(value[key])
			return encoded_dictionary
		_:
			push_error("Unsupported grid occupant value type: %s" % type_string(typeof(value)))
			return null


func _decode_variant(value: Variant) -> Variant:
	if typeof(value) == TYPE_ARRAY:
		var decoded_array: Array = []
		for item: Variant in value:
			decoded_array.append(_decode_variant(item))
		return decoded_array
	if typeof(value) != TYPE_DICTIONARY:
		return value
	var type_tag := String(value.get("__grid_type", ""))
	match type_tag:
		"StringName":
			return StringName(value.get("value", ""))
		"Vector2i":
			return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
		"Vector2":
			return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
		"Color":
			return Color.from_string(String(value.get("value", "00000000")), Color.TRANSPARENT)
		_:
			var decoded_dictionary: Dictionary = {}
			for key: Variant in value:
				decoded_dictionary[key] = _decode_variant(value[key])
			return decoded_dictionary
