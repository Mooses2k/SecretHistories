extends Node

# This script intends to create one of each setting type on the settings screen
# For testing purposes only

const GROUP_NAME : String = "Test Settings"

const SETTING_BOOL_F : String = "Boolean Setting False Default"
const SETTING_BOOL_T : String = "Boolean Setting True Default"
const SETTING_INT : String = "Integer Number Setting"
const SETTING_ENUM : String = "Enumeration Setting"
const SETTING_FLOAT : String = "Floating Point Number Setting"

const SETTINGS = [
	SETTING_BOOL_F,
	SETTING_BOOL_T,
	SETTING_INT,
	SETTING_ENUM,
	SETTING_FLOAT,
]

func _ready():
	Settings.add_bool_setting(SETTING_BOOL_F, false)
	Settings.add_bool_setting(SETTING_BOOL_T, true)
	Settings.add_float_setting(SETTING_FLOAT, -16.0, 16.0, 1.0, 4.0)
	Settings.add_int_setting(SETTING_INT, -128, 127, 1, 84)
	Settings.add_enum_setting(SETTING_ENUM, PoolStringArray(SETTINGS), 3)
	Settings.connect("setting_changed", self, "on_setting_changed")

func on_setting_changed(setting_name, old_value, new_value):
	if SETTINGS.has(setting_name):
		print_debug("Setting '", setting_name, "' changed from ", old_value, " to ", new_value)
	pass
	
