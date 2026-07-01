extends Node

signal navigation_requested(destination: StringName)
signal level_started(level_number: int, level_data: Dictionary)
signal move_recorded(valid: bool, moves: int)
signal level_completed(level_number: int, moves: int)

enum RunState { HOME, PLAYING, PAUSED, COMPLETE }

var state := RunState.HOME
var current_level := 1
var moves := 0
var valid_moves := 0


func _ready() -> void:
	current_level = int(SaveManager.get_progress(&"last_played_level", 1))


func start_new_game() -> void:
	start_level(1)


func continue_game() -> void:
	start_level(int(SaveManager.get_progress(&"last_played_level", 1)))


func start_level(level_number: int) -> void:
	current_level = max(level_number, 1)
	moves = 0
	valid_moves = 0
	state = RunState.PLAYING
	var level_data := LevelManager.get_level(current_level)
	navigation_requested.emit(&"game")
	level_started.emit(current_level, level_data)


func record_move(valid: bool) -> void:
	if state != RunState.PLAYING:
		return
	moves += 1
	if valid:
		valid_moves += 1
		SaveManager.increment_stat(&"valid_moves", 1, false)
	else:
		SaveManager.increment_stat(&"blocked_taps", 1, false)
	move_recorded.emit(valid, moves)


func complete_level() -> void:
	if state != RunState.PLAYING:
		return
	state = RunState.COMPLETE
	SaveManager.update_progress(current_level, moves)
	level_completed.emit(current_level, moves)


func next_level() -> void:
	start_level(current_level + 1)


func restart_level() -> void:
	start_level(current_level)


func go_home() -> void:
	state = RunState.HOME
	navigation_requested.emit(&"home")


func set_paused(paused: bool) -> void:
	if state == RunState.COMPLETE:
		return
	state = RunState.PAUSED if paused else RunState.PLAYING
	get_tree().paused = paused
