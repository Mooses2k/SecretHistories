extends Node

# This script intends to create one of each setting type on the settings screen
# For testing purposes only


const GROUP_NAME : String = "Game Settings"

const SETTING_ADS: String = "Hold ADS (Aim Down Sights)"
const SETTING_CROUCH : String = "Hold Crouch"


func _ready():
	Settings.add_bool_setting(SETTING_ADS, GameManager.is_ads_hold)
	Settings.set_setting_group(SETTING_ADS, GROUP_NAME)
	Settings.add_bool_setting(SETTING_CROUCH, GameManager.is_crouch_hold)
	Settings.set_setting_group(SETTING_CROUCH, GROUP_NAME)
	Settings.connect("setting_changed", self, "on_setting_changed")


func on_setting_changed(setting_name, old_value, new_value):
	match setting_name:
		SETTING_ADS:
			GameManager.is_ads_hold = new_value
			emit_signal("fullscreen_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_CROUCH:
			GameManager.is_crouch_hold = new_value
			emit_signal("gui_scale_changed", new_value)
			SettingsConfig.save_settings()
	pass
