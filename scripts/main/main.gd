extends Node

const HOME_SCENE := preload("res://scenes/home/home.tscn")
const GAME_SCENE := preload("res://scenes/game/game.tscn")

@onready var screen_host: Control = %ScreenHost

var _current_screen: Control


func _ready() -> void:
	GameManager.navigation_requested.connect(_on_navigation_requested)
	_show_screen(&"home")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"android_back"):
		get_viewport().set_input_as_handled()
		if GameManager.state == GameManager.RunState.HOME:
			get_tree().quit()
		else:
			GameManager.go_home()


func _on_navigation_requested(destination: StringName) -> void:
	_show_screen(destination)


func _show_screen(destination: StringName) -> void:
	if is_instance_valid(_current_screen):
		_current_screen.queue_free()
		_current_screen = null
	match destination:
		&"game":
			_current_screen = GAME_SCENE.instantiate()
		_:
			_current_screen = HOME_SCENE.instantiate()
	screen_host.add_child(_current_screen)
