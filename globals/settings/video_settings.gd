extends Node


signal fullscreen_changed(new_value)
signal gui_scale_changed(new_value)

const GROUP_NAME : String = "Video Settings"

const SETTING_FULLSCREEN : String = "Fullscreen"

const SETTING_BRIGHTNESS : String = "Brightness"
const BRIGHTNESS_MIN = 0.1
const BRIGHTNESS_MAX = 5.0
const BRIGHTNESS_STEP = 0.1
const BRIGHTNESS_DEFAULT = 1.0

const SETTING_GUI_SCALE : String = "GUI Scale"
const GUI_SCALE_MIN = 0.5
const GUI_SCALE_MAX = 2.0
const GUI_SCALE_STEP = 0.25
const GUI_SCALE_DEFAULT = 1.0

var fullscreen_enabled : bool setget set_fullscreen_enabled, get_fullscreen_enabled
var brightness : bool setget set_brightness, get_brightness
var gui_scale : float setget set_gui_scale, get_gui_scale


func _ready():
	Settings.add_bool_setting(SETTING_FULLSCREEN, OS.window_fullscreen)
	Settings.set_setting_group(SETTING_FULLSCREEN, GROUP_NAME)
	
	Settings.add_float_setting(SETTING_BRIGHTNESS, BRIGHTNESS_MIN, BRIGHTNESS_MAX, BRIGHTNESS_STEP, BRIGHTNESS_DEFAULT)
	Settings.set_setting_group(SETTING_BRIGHTNESS, GROUP_NAME)
	
	Settings.add_float_setting(SETTING_GUI_SCALE, GUI_SCALE_MIN, GUI_SCALE_MAX, GUI_SCALE_STEP, GUI_SCALE_DEFAULT)
	Settings.set_setting_group(SETTING_GUI_SCALE, GROUP_NAME)
	
	Settings.connect("setting_changed", self, "on_setting_changed")


func set_fullscreen_enabled(value : bool):
	Settings.set_setting(SETTING_FULLSCREEN, value)

func get_fullscreen_enabled() -> bool:
	return Settings.get_setting(SETTING_FULLSCREEN)


func set_brightness(value : bool):
	Settings.set_setting(SETTING_BRIGHTNESS, value)

func get_brightness() -> bool:
	return Settings.get_setting(SETTING_BRIGHTNESS)


func set_gui_scale(value : float):
	Settings.set_setting(SETTING_GUI_SCALE, value)

func get_gui_scale() -> float:
	return Settings.get_setting(SETTING_GUI_SCALE)


func on_setting_changed(setting_name, old_value, new_value):
	match setting_name:
		SETTING_FULLSCREEN:
			OS.window_fullscreen = new_value
			fullscreen_enabled = new_value
			emit_signal("fullscreen_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_BRIGHTNESS:
			if is_instance_valid(GameManager.game):   # If the game is loaded, change immediately
				GameManager.game.level.set_brightness()
			brightness = new_value
			emit_signal("brightness_change", new_value)   # TODO: make this signal
			SettingsConfig.save_settings()
		SETTING_GUI_SCALE:
			gui_scale = new_value
			emit_signal("gui_scale_changed", new_value)
			SettingsConfig.save_settings()
