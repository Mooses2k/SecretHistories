extends Node

# This script intends to create one of each setting type on the settings screen
# For testing purposes only

const GROUP_NAME : String = "Game Settings"

## Gunplay section: the seed of the future fiddly-gun-mechanics settings.
const GUNPLAY_GROUP_NAME : String = "Gunplay"

const SETTING_ADS: String = "Hold ADS (Aim Down Sights)"
const SETTING_CROUCH : String = "Hold Crouch"
const SETTING_AUTO_SWITCH_WEAPON: String = "Auto-switch weapons on throw"
## Realistic shell ejection: OFF (default, arcade) ejects only the chambers'
## spent cases on a reload press; ON (realistic) ejects every chamber, one
## casing each, plus each unfired round again as a loose-ammo pickup item in
## the world. Read at press time through realistic_shell_ejection_enabled().
const SETTING_REALISTIC_SHELL_EJECTION : String = "Realistic Shell Ejection"
const AUTO_SWITCH_WEAPON_DEFAULT : int = 0  # Index of default option (Next same type then all)
const CROUCH_DEFAULT : bool = false
const ADS_DEFAULT : bool = true
const REALISTIC_SHELL_EJECTION_DEFAULT : bool = false

var crouch_hold_enabled : bool: get = get_crouch_hold, set = set_crouch_hold
var ads_hold_enabled : bool: get = get_ads_hold, set = set_ads_hold
var auto_switch_weapon : int: get = get_auto_switch_weapon, set = set_auto_switch_weapon
var is_first_run : bool: get = get_first_run, set = set_first_run

var auto_switch_options = PackedStringArray(["Next same type then all", "Next same type only", "None"])

func _ready():
	Settings.add_bool_setting(SETTING_ADS, ADS_DEFAULT)
	Settings.set_setting_group(SETTING_ADS, GROUP_NAME)
	Settings.add_bool_setting(SETTING_CROUCH, CROUCH_DEFAULT)
	Settings.set_setting_group(SETTING_CROUCH, GROUP_NAME)
	Settings.add_enum_setting(SETTING_AUTO_SWITCH_WEAPON, auto_switch_options, AUTO_SWITCH_WEAPON_DEFAULT)
	Settings.set_setting_group(SETTING_AUTO_SWITCH_WEAPON, GROUP_NAME)
	Settings.add_bool_setting(SETTING_REALISTIC_SHELL_EJECTION, REALISTIC_SHELL_EJECTION_DEFAULT)
	Settings.set_setting_group(SETTING_REALISTIC_SHELL_EJECTION, GUNPLAY_GROUP_NAME)
	# is_first_run is handled as a private variable, not registered with Settings singleton
	Settings.connect("setting_changed", Callable(self, "on_setting_changed"))


func set_crouch_hold(value : bool):
	Settings.set_setting(SETTING_CROUCH, value)

func get_crouch_hold() -> bool:
	return Settings.get_setting(SETTING_CROUCH)


func set_ads_hold(value : bool):
	Settings.set_setting(SETTING_ADS, value)

func get_ads_hold() -> bool:
	return Settings.get_setting(SETTING_ADS)


func set_auto_switch_weapon(value : int):
	Settings.set_setting(SETTING_AUTO_SWITCH_WEAPON, value)

func get_auto_switch_weapon() -> int:
	return Settings.get_setting(SETTING_AUTO_SWITCH_WEAPON)


## Read gate for the ejection mode, null-safe like the KeyInputSettings
## gameplay gates: an unregistered setting reads as the OFF default, so
## headless and editor runs never dereference a missing entry.
func realistic_shell_ejection_enabled() -> bool:
	if not Settings.has_setting(SETTING_REALISTIC_SHELL_EJECTION):
		return false
	return bool(Settings.get_setting(SETTING_REALISTIC_SHELL_EJECTION))


func set_realistic_shell_ejection(enabled : bool):
	Settings.set_setting(SETTING_REALISTIC_SHELL_EJECTION, enabled)


func set_first_run(value : bool):
	is_first_run = value

func get_first_run() -> bool:
	return is_first_run


func on_setting_changed(setting_name, _old_value, _new_value):
	match setting_name:
		SETTING_ADS:
			#ads_hold_enabled = new_value
			SettingsConfig.save_settings()
		SETTING_CROUCH:
			#crouch_hold_enabled = new_value
			SettingsConfig.save_settings()
		SETTING_AUTO_SWITCH_WEAPON:
			SettingsConfig.save_settings()
		SETTING_REALISTIC_SHELL_EJECTION:
			SettingsConfig.save_settings()
		"is_first_run":
			SettingsConfig.save_settings()
