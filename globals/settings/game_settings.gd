extends Node

# This script intends to create one of each setting type on the settings screen
# For testing purposes only

const GROUP_NAME : String = "Game Settings"

const SETTING_ADS: String = "Hold ADS (Aim Down Sights)"
const SETTING_CROUCH : String = "Hold Crouch"
const CROUCH_DEFAULT : bool = false
const ADS_DEFAULT : bool = true

var crouch_hold_enabled : bool: get = get_crouch_hold, set = set_crouch_hold
var ads_hold_enabled : bool: get = get_ads_hold, set = set_ads_hold


func _ready():
	Settings.add_bool_setting(SETTING_ADS, ADS_DEFAULT)
	Settings.set_setting_group(SETTING_ADS, GROUP_NAME)
	Settings.add_bool_setting(SETTING_CROUCH, CROUCH_DEFAULT)
	Settings.set_setting_group(SETTING_CROUCH, GROUP_NAME)
	Settings.connect("setting_changed", Callable(self, "on_setting_changed"))


func set_crouch_hold(value : bool):
	Settings.set_setting(SETTING_CROUCH, value)

func get_crouch_hold() -> bool:
	return Settings.get_setting(SETTING_CROUCH)


func set_ads_hold(value : bool):
	Settings.set_setting(SETTING_ADS, value)

func get_ads_hold() -> bool:
	return Settings.get_setting(SETTING_ADS)


func on_setting_changed(setting_name, old_value, new_value):
	match setting_name:
		SETTING_ADS:
			#ads_hold_enabled = new_value
			SettingsConfig.save_settings()
		SETTING_CROUCH:
			#crouch_hold_enabled = new_value
			SettingsConfig.save_settings()
