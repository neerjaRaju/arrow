extends SceneTree

const LevelManagerScript := preload("res://autoload/level_manager.gd")


func _initialize() -> void:
	var level_manager: Node = LevelManagerScript.new()
	for level_number in range(1, 65):
		var level_data: Dictionary = level_manager.get_level(level_number)
		assert(_is_solvable(level_data), "Level %d is not solvable" % level_number)
	level_manager.free()
	print("Validated 64 deterministic, solvable levels.")
	quit()


func _is_solvable(level_data: Dictionary) -> bool:
	var board_size: int = level_data["size"]
	var arrows: Array = level_data["arrows"]
	var occupied: Dictionary = {}
	for arrow: Dictionary in arrows:
		occupied[arrow["cell"]] = arrow

	for index in range(arrows.size() - 1, -1, -1):
		var arrow: Dictionary = arrows[index]
		var cell: Vector2i = arrow["cell"]
		var direction: Vector2i = arrow["direction"]
		var cursor := cell + direction
		while cursor.x >= 0 and cursor.y >= 0 and cursor.x < board_size and cursor.y < board_size:
			if occupied.has(cursor):
				return false
			cursor += direction
		occupied.erase(cell)
	return occupied.is_empty()
