extends Control

@onready var continue_button: Button = %ContinueButton
@onready var sound_button: Button = %SoundButton
@onready var music_button: Button = %MusicButton


func _ready() -> void:
	%PlayButton.pressed.connect(GameManager.start_new_game)
	continue_button.pressed.connect(GameManager.continue_game)
	%SoundButton.pressed.connect(_toggle_sound)
	%MusicButton.pressed.connect(_toggle_music)
	continue_button.visible = int(SaveManager.get_progress(&"highest_unlocked_level", 1)) > 1
	_update_audio_labels()


func _toggle_sound() -> void:
	AudioManager.set_sound_enabled(not AudioManager.sound_enabled)
	_update_audio_labels()


func _toggle_music() -> void:
	AudioManager.set_music_enabled(not AudioManager.music_enabled)
	_update_audio_labels()


func _update_audio_labels() -> void:
	sound_button.text = "Sound: %s" % ("On" if AudioManager.sound_enabled else "Off")
	music_button.text = "Music: %s" % ("On" if AudioManager.music_enabled else "Off")
