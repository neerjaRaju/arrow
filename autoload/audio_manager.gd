extends Node

signal music_enabled_changed(enabled: bool)
signal sound_enabled_changed(enabled: bool)

const MUSIC_BUS := &"Music"
const SOUND_BUS := &"Sound"
const UI_PLAYER_COUNT := 4

var music_enabled := true
var sound_enabled := true
var _music_player: AudioStreamPlayer
var _ui_players: Array[AudioStreamPlayer] = []
var _next_ui_player := 0


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SOUND_BUS)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)
	for index in UI_PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.name = "SoundPlayer%d" % index
		player.bus = SOUND_BUS
		add_child(player)
		_ui_players.append(player)
	music_enabled = bool(SaveManager.get_setting(&"music_enabled", true))
	sound_enabled = bool(SaveManager.get_setting(&"sound_enabled", true))
	_apply_bus_states()


func set_music_enabled(enabled: bool) -> void:
	if music_enabled == enabled:
		return
	music_enabled = enabled
	_apply_bus_states()
	SaveManager.set_setting(&"music_enabled", enabled)
	music_enabled_changed.emit(enabled)


func set_sound_enabled(enabled: bool) -> void:
	if sound_enabled == enabled:
		return
	sound_enabled = enabled
	_apply_bus_states()
	SaveManager.set_setting(&"sound_enabled", enabled)
	sound_enabled_changed.emit(enabled)


func play_music(stream: AudioStream, fade_seconds: float = 0.25) -> void:
	if stream == null:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.volume_db = -30.0 if fade_seconds > 0.0 else 0.0
	_music_player.play()
	if fade_seconds > 0.0:
		create_tween().tween_property(_music_player, "volume_db", 0.0, fade_seconds)


func stop_music(fade_seconds: float = 0.2) -> void:
	if not _music_player.playing:
		return
	if fade_seconds <= 0.0:
		_music_player.stop()
		return
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -30.0, fade_seconds)
	tween.tween_callback(_music_player.stop)


func play_sound(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null or not sound_enabled or _ui_players.is_empty():
		return
	var player := _ui_players[_next_ui_player]
	_next_ui_player = (_next_ui_player + 1) % _ui_players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _apply_bus_states() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), not music_enabled)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SOUND_BUS), not sound_enabled)
