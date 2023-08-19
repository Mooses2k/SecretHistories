extends Node


const GROUP_NAME : String = "Input Settings"

const SETTING_MOUSE_SENSITIVITY : String = "Mouse Sensitivity"

const MAX_VALUE = 8.0
const STEP_VALUE = 0.05
const MIN_VALUE = -8.0
const DEFAULT_VALUE = 0.2

var setting_mouse_sensitivity : float setget set_mouse_sensitivity, get_mouse_sensitivity


func _ready():
	Settings.add_float_setting(SETTING_MOUSE_SENSITIVITY, MIN_VALUE, MAX_VALUE, STEP_VALUE, DEFAULT_VALUE)
	Settings.set_setting_group(SETTING_MOUSE_SENSITIVITY, GROUP_NAME)
	
	Settings.connect("setting_changed", self, "on_setting_changed")


func set_mouse_sensitivity(value : float):
	Settings.set_setting(SETTING_MOUSE_SENSITIVITY, value)

func get_mouse_sensitivity() -> float:
	return Settings.get_setting(SETTING_MOUSE_SENSITIVITY)


func on_setting_changed(setting_name, old_value, new_value):
	match setting_name:
		SETTING_MOUSE_SENSITIVITY:
			setting_mouse_sensitivity = new_value
			SettingsConfig.save_settings()
			
			print(setting_mouse_sensitivity)
			print(SETTING_MOUSE_SENSITIVITY)
