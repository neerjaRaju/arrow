extends Control

@onready var board = %Board
@onready var level_label: Label = %LevelLabel
@onready var moves_label: Label = %MovesLabel
@onready var completion_overlay: Control = %CompletionOverlay
@onready var completion_title: Label = %CompletionTitle
@onready var completion_detail: Label = %CompletionDetail


func _ready() -> void:
	GameManager.level_started.connect(_on_level_started)
	GameManager.move_recorded.connect(_on_move_recorded)
	GameManager.level_completed.connect(_on_level_completed)
	board.arrow_selected.connect(_on_arrow_selected)
	board.board_cleared.connect(GameManager.complete_level)
	%HomeButton.pressed.connect(GameManager.go_home)
	%RestartButton.pressed.connect(GameManager.restart_level)
	%NextButton.pressed.connect(GameManager.next_level)
	%CompleteHomeButton.pressed.connect(GameManager.go_home)
	if GameManager.state in [GameManager.RunState.PLAYING, GameManager.RunState.COMPLETE]:
		_on_level_started(GameManager.current_level, LevelManager.get_level(GameManager.current_level))


func _exit_tree() -> void:
	if GameManager.level_started.is_connected(_on_level_started):
		GameManager.level_started.disconnect(_on_level_started)
	if GameManager.move_recorded.is_connected(_on_move_recorded):
		GameManager.move_recorded.disconnect(_on_move_recorded)
	if GameManager.level_completed.is_connected(_on_level_completed):
		GameManager.level_completed.disconnect(_on_level_completed)


func _on_level_started(level_number: int, level_data: Dictionary) -> void:
	completion_overlay.hide()
	level_label.text = "LEVEL %d" % level_number
	moves_label.text = "MOVES  0"
	board.setup(level_data)


func _on_arrow_selected(valid: bool) -> void:
	GameManager.record_move(valid)


func _on_move_recorded(_valid: bool, move_count: int) -> void:
	moves_label.text = "MOVES  %d" % move_count


func _on_level_completed(level_number: int, move_count: int) -> void:
	completion_title.text = "Level %d cleared!" % level_number
	completion_detail.text = "%d moves • Next puzzle unlocked" % move_count
	completion_overlay.show()
