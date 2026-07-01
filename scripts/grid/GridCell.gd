class_name GridCell
extends Node2D

## Lightweight visual cell used by [GridManager].
##
## GridCell has no input handler and no gameplay dependency. A manager performs
## one touch hit-test for the entire grid, while cells redraw only when their
## visual state changes. This keeps a 10x10 board inexpensive on mobile.

const DEFAULT_BACKGROUND := Color("121a2c")
const OCCUPIED_BACKGROUND := Color("18253c")
const HIGHLIGHT_BACKGROUND := Color("244b59")
const SELECTED_BACKGROUND := Color("285e68")
const BORDER_COLOR := Color("344660")
const HIGHLIGHT_BORDER := Color("6ee7d8")
const CONTENT_COLOR := Color("6ee7d8")
const DEBUG_LABEL_COLOR := Color("ffcc66")

var coordinate := Vector2i.ZERO
var cell_size := 64.0
var is_occupied := false
var is_highlighted := false
var is_selected := false
var debug_label_visible := false
var content_text := ""
var content_color := CONTENT_COLOR
var _flash_color := Color.TRANSPARENT


## Configures immutable layout data for this cell.
func configure(grid_coordinate: Vector2i, size_in_pixels: float) -> void:
	coordinate = grid_coordinate
	cell_size = maxf(size_in_pixels, 1.0)
	position = Vector2(coordinate) * cell_size
	queue_redraw()


## Updates occupancy styling without assigning gameplay data to the cell.
func set_occupied(occupied: bool) -> void:
	if is_occupied == occupied:
		return
	is_occupied = occupied
	queue_redraw()


## Sets an optional centered label, used by Arrow Escape for arrow glyphs.
func set_content(text: String, color: Color = CONTENT_COLOR) -> void:
	content_text = text
	content_color = color
	queue_redraw()


## Applies the hover/path-preview highlight state.
func set_highlighted(highlighted: bool) -> void:
	if is_highlighted == highlighted:
		return
	is_highlighted = highlighted
	queue_redraw()


## Applies the persistent selection state.
func set_selected(selected: bool) -> void:
	if is_selected == selected:
		return
	is_selected = selected
	queue_redraw()


## Shows the grid coordinate label used by debug builds and unit-test scenes.
func set_debug_label_visible(visible: bool) -> void:
	if debug_label_visible == visible:
		return
	debug_label_visible = visible
	queue_redraw()


## Briefly flashes a cell without allocating an AnimationPlayer.
func flash(color: Color, duration: float = 0.16) -> void:
	_flash_color = color
	queue_redraw()
	var tween := create_tween()
	tween.tween_interval(maxf(duration, 0.01))
	tween.tween_callback(func() -> void:
		_flash_color = Color.TRANSPARENT
		queue_redraw()
	)


func _draw() -> void:
	var inset := 2.0
	var rect := Rect2(Vector2.ONE * inset, Vector2.ONE * (cell_size - inset * 2.0))
	var background := DEFAULT_BACKGROUND
	if is_occupied:
		background = OCCUPIED_BACKGROUND
	if is_highlighted:
		background = HIGHLIGHT_BACKGROUND
	if is_selected:
		background = SELECTED_BACKGROUND
	if _flash_color.a > 0.0:
		background = _flash_color

	draw_rect(rect, background, true)
	var border := HIGHLIGHT_BORDER if is_highlighted or is_selected else BORDER_COLOR
	var border_width := 3.0 if is_highlighted or is_selected else 1.0
	draw_rect(rect, border, false, border_width)

	var font := ThemeDB.fallback_font
	if not content_text.is_empty():
		var font_size := maxi(14, floori(cell_size * 0.48))
		var text_size := font.get_string_size(content_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var baseline := Vector2(
			(cell_size - text_size.x) * 0.5,
			(cell_size + text_size.y) * 0.5 - font.get_descent(font_size)
		)
		draw_string(font, baseline, content_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, content_color)

	if debug_label_visible:
		var debug_font_size := maxi(9, floori(cell_size * 0.18))
		var label := "%d,%d" % [coordinate.x, coordinate.y]
		draw_string(font, Vector2(5.0, debug_font_size + 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, debug_font_size, DEBUG_LABEL_COLOR)
