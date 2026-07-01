extends Control

@onready var surface: Control = %Surface
@onready var grid: GridManager = %GridManager
@onready var size_label: Label = %SizeLabel
@onready var status_label: Label = %StatusLabel

var _side := 7


func _ready() -> void:
	%SmallerButton.pressed.connect(_resize.bind(-1))
	%BiggerButton.pressed.connect(_resize.bind(1))
	%DebugButton.pressed.connect(_toggle_debug)
	%SerializeButton.pressed.connect(_round_trip)
	grid.cell_selected.connect(_on_cell_selected)
	surface.resized.connect(_center_grid)
	_rebuild()


func _resize(delta: int) -> void:
	_side = clampi(_side + delta, GridManager.MIN_BOARD_SIZE, GridManager.MAX_BOARD_SIZE)
	_rebuild()


func _rebuild() -> void:
	var side_pixels := minf(surface.size.x, surface.size.y) - 24.0
	var debug_cell_size := floorf(side_pixels / float(_side))
	grid.configure(Vector2i(_side, _side), debug_cell_size)
	for index in _side:
		var cell := Vector2i(index, index)
		grid.set_occupant(cell, {"kind": "debug", "index": index})
		grid.get_cell_node(cell).set_content("●", Color("ffcc66"))
	_center_grid()
	size_label.text = "%d × %d" % [_side, _side]
	status_label.text = "Tap a cell to inspect or toggle occupancy"


func _center_grid() -> void:
	var pixel_size := Vector2(grid.board_size) * grid.cell_size
	grid.position = (surface.size - pixel_size) * 0.5


func _on_cell_selected(cell: Vector2i) -> void:
	grid.highlight_cell(cell)
	if grid.is_occupied(cell):
		grid.clear_occupant(cell)
		grid.get_cell_node(cell).set_content("")
		status_label.text = "Cleared %s • %d occupied" % [cell, grid.occupied_count()]
	else:
		grid.set_occupant(cell, {"kind": "debug", "cell": cell})
		grid.get_cell_node(cell).set_content("●", Color("ffcc66"))
		status_label.text = "Occupied %s • %d occupied" % [cell, grid.occupied_count()]


func _toggle_debug() -> void:
	grid.debug_grid_drawing = not grid.debug_grid_drawing
	%DebugButton.text = "DEBUG: %s" % ("ON" if grid.debug_grid_drawing else "OFF")


func _round_trip() -> void:
	var json := JSON.stringify(grid.serialize_grid())
	var decoded: Variant = JSON.parse_string(json)
	var restored := typeof(decoded) == TYPE_DICTIONARY and grid.deserialize_grid(decoded)
	_repaint_occupants()
	_center_grid()
	status_label.text = "JSON round trip: %s • %d bytes" % ["OK" if restored else "FAILED", json.length()]


func _repaint_occupants() -> void:
	for y in grid.board_size.y:
		for x in grid.board_size.x:
			var cell := Vector2i(x, y)
			var cell_node := grid.get_cell_node(cell)
			cell_node.set_content("●" if grid.is_occupied(cell) else "", Color("ffcc66"))
