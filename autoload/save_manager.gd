extends Node

signal data_loaded(data: Dictionary)
signal data_saved(data: Dictionary)
signal save_failed(reason: String)

const SAVE_VERSION := 1
const SAVE_PATH := "user://arrow_escape_save.json"
const BACKUP_PATH := "user://arrow_escape_save.backup.json"
const TEMP_PATH := "user://arrow_escape_save.tmp.json"

var data: Dictionary = {}


func _ready() -> void:
	load_data()


func default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"progress": {
			"highest_unlocked_level": 1,
			"last_played_level": 1,
			"completed_levels": {},
		},
		"settings": {
			"music_enabled": true,
			"sound_enabled": true,
			"haptics_enabled": true,
		},
		"stats": {
			"levels_completed": 0,
			"valid_moves": 0,
			"blocked_taps": 0,
		},
	}


func load_data() -> void:
	data = _read_valid_save(SAVE_PATH)
	if data.is_empty():
		data = _read_valid_save(BACKUP_PATH)
	if data.is_empty():
		data = default_data()
		save_data()
	else:
		data = _migrate(data)
	data_loaded.emit(data.duplicate(true))


func save_data() -> bool:
	var payload := JSON.stringify(data, "\t")
	var temp_file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if temp_file == null:
		save_failed.emit("Unable to open temporary save file (error %s)." % FileAccess.get_open_error())
		return false
	temp_file.store_string(payload)
	temp_file.flush()
	temp_file.close()

	if FileAccess.file_exists(SAVE_PATH):
		var previous := FileAccess.get_file_as_string(SAVE_PATH)
		var backup_file := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		if backup_file != null:
			backup_file.store_string(previous)
			backup_file.close()
		DirAccess.remove_absolute(SAVE_PATH)

	var rename_error := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if rename_error != OK:
		save_failed.emit("Unable to finalize save file (error %s)." % rename_error)
		return false
	data_saved.emit(data.duplicate(true))
	return true


func get_setting(key: StringName, fallback: Variant = null) -> Variant:
	return data.get("settings", {}).get(String(key), fallback)


func set_setting(key: StringName, value: Variant) -> void:
	var settings: Dictionary = data.get("settings", {})
	settings[String(key)] = value
	data["settings"] = settings
	save_data()


func get_progress(key: StringName, fallback: Variant = null) -> Variant:
	return data.get("progress", {}).get(String(key), fallback)


func update_progress(level: int, moves: int) -> void:
	var progress: Dictionary = data.get("progress", {})
	var completed: Dictionary = progress.get("completed_levels", {})
	var level_key := str(level)
	var previous_best := int(completed.get(level_key, 0))
	if previous_best == 0 or moves < previous_best:
		completed[level_key] = moves
	progress["completed_levels"] = completed
	progress["last_played_level"] = level + 1
	progress["highest_unlocked_level"] = max(int(progress.get("highest_unlocked_level", 1)), level + 1)
	data["progress"] = progress
	increment_stat("levels_completed", 1, false)
	save_data()


func increment_stat(key: StringName, amount: int = 1, persist: bool = true) -> void:
	var stats: Dictionary = data.get("stats", {})
	stats[String(key)] = int(stats.get(String(key), 0)) + amount
	data["stats"] = stats
	if persist:
		save_data()


func _read_valid_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var candidate: Dictionary = parsed
	if not candidate.has("version") or not candidate.has("progress") or not candidate.has("settings"):
		return {}
	return candidate


func _migrate(source: Dictionary) -> Dictionary:
	var merged := default_data()
	_merge_dictionary(merged, source)
	merged["version"] = SAVE_VERSION
	return merged


func _merge_dictionary(target: Dictionary, source: Dictionary) -> void:
	for key: Variant in source:
		if target.has(key) and typeof(target[key]) == TYPE_DICTIONARY and typeof(source[key]) == TYPE_DICTIONARY:
			_merge_dictionary(target[key], source[key])
		else:
			target[key] = source[key]
