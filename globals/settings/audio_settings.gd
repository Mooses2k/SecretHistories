extends Node


const GROUP_NAME : String = "Audio Settings"

const SETTING_MASTER_VOLUME : String = "Master Volume"
const SETTING_MUSIC_VOLUME : String = "Music Volume"
const SETTING_EFFECTS_VOLUME : String = "Effects Volume"
const SETTING_VOICE_VOLUME : String = "Voice Volume"

onready var bus_master = AudioServer.get_bus_index("Master") # 0
onready var bus_music = AudioServer.get_bus_index("Music") # 1
onready var bus_effects = AudioServer.get_bus_index("Effects") # 2
onready var bus_voice = AudioServer.get_bus_index("Voice") # 3

const MAX_VALUE = 100.0
const STEP_VALUE = 1.0
const MIN_VALUE = 0.0

var setting_master_volume : float setget set_master_volume, get_master_volume
var setting_music_volume : float setget set_music_volume, get_music_volume
var setting_effects_volume : float setget set_effects_volume, get_effects_volume
var setting_voice_volume : float setget set_voice_volume, get_voice_volume


func _ready():
	Settings.add_float_setting(SETTING_MASTER_VOLUME, MIN_VALUE, MAX_VALUE, STEP_VALUE, get_volume(bus_master))
	Settings.set_setting_group(SETTING_MASTER_VOLUME, GROUP_NAME)
	Settings.add_float_setting(SETTING_MUSIC_VOLUME, MIN_VALUE, MAX_VALUE, STEP_VALUE, get_volume(bus_music))
	Settings.set_setting_group(SETTING_MUSIC_VOLUME, GROUP_NAME)
	Settings.add_float_setting(SETTING_EFFECTS_VOLUME, MIN_VALUE, MAX_VALUE, STEP_VALUE, get_volume(bus_effects))
	Settings.set_setting_group(SETTING_EFFECTS_VOLUME, GROUP_NAME)
	Settings.add_float_setting(SETTING_VOICE_VOLUME, MIN_VALUE, MAX_VALUE, STEP_VALUE, get_volume(bus_voice))
	Settings.set_setting_group(SETTING_VOICE_VOLUME, GROUP_NAME)
	Settings.connect("setting_changed", self, "on_setting_changed")


func set_master_volume(value : float):
	Settings.set_setting(SETTING_MASTER_VOLUME, value)

func get_master_volume() -> float:
	return Settings.get_setting(SETTING_MASTER_VOLUME)


func set_music_volume(value : float):
	Settings.set_setting(SETTING_MUSIC_VOLUME, value)

func get_music_volume() -> float:
	return Settings.get_setting(SETTING_MUSIC_VOLUME)


func set_effects_volume(value : float):
	Settings.set_setting(SETTING_EFFECTS_VOLUME, value)

func get_effects_volume() -> float:
	return Settings.get_setting(SETTING_EFFECTS_VOLUME)


func set_voice_volume(value : float):
	Settings.set_setting(SETTING_VOICE_VOLUME, value)

func get_voice_volume() -> float:
	return Settings.get_setting(SETTING_VOICE_VOLUME)


func set_volume(idx : int, value : float):
	AudioServer.set_bus_volume_db(idx, linear2db(value/MAX_VALUE))
	
	match idx:
		0:
			GameManager.master_volume = linear2db(value/MAX_VALUE)
		1:
			GameManager.music_volume = linear2db(value/MAX_VALUE)
		2:
			GameManager.effects_volume = linear2db(value/MAX_VALUE)
		3:
			GameManager.voice_volume = linear2db(value/MAX_VALUE)
		
	SettingsConfig.save_settings()


func get_volume(idx : int) -> float:
#	return db2linear(AudioServer.get_bus_volume_db(idx)) * MAX_VALUE
	match idx:
		0:
			return db2linear(GameManager.master_volume) * MAX_VALUE
		1:
			return db2linear(GameManager.music_volume) * MAX_VALUE
		2:
			return db2linear(GameManager.effects_volume) * MAX_VALUE
		3:
			return db2linear(GameManager.voice_volume) * MAX_VALUE
		_:
			return db2linear(GameManager.master_volume) * MAX_VALUE


func on_setting_changed(setting_name, old_value, new_value):
	match setting_name:
		SETTING_MASTER_VOLUME:
			set_volume(bus_master, new_value)
		SETTING_MUSIC_VOLUME:
			set_volume(bus_music, new_value)
		SETTING_EFFECTS_VOLUME:
			set_volume(bus_effects, new_value)
		SETTING_VOICE_VOLUME:
			set_volume(bus_voice, new_value)
	pass
