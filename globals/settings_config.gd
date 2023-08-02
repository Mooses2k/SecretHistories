extends Node

var game_manager : GDScript = preload("res://globals/game_manager.gd")

var file_name = "%s://globals/settings/settingsConfig.dict" % ("user" if OS.has_feature("standalone") else "res")
var file_name_default = "%s://globals/settings/defaultSettConfig.dict" % ("user" if OS.has_feature("standalone") else "res")

var setting_key = false

enum value_types {
	BOOL,
	FLOAT
}

var value_prefixes = [
	"bool", 
	"float"
]

var settings_names = [
	"is_crouch_hold",
	"is_ads_hold",
	"mouse_sensitivity",
	"master_volume",
	"music_volume",
	"effects_volume",
	"voice_volume",
	"full_screen",
	"gui_scale"
]


func _ready():
	load_sett_config()


func gen_dict_from_settings() -> Dictionary:
	var actions = InputMap.get_actions()
	var config = Dictionary()
	var value_type = value_types.BOOL
	
	for setting in settings_names:
		match setting:
			"is_crouch_hold":
				config[setting] = "%s(%s)" % [value_prefixes[value_types.BOOL], str(GameSettings.crouch_hold_enabled)]
			"is_ads_hold":
				config[setting] = "%s(%s)" % [value_prefixes[value_types.BOOL], str(GameSettings.ads_hold_enabled)]
			"mouse_sensitivity":
				config[setting] = "%s(%s)" % [value_prefixes[value_types.FLOAT], str(InputSettings.setting_mouse_sensitivity)]
			"master_volume":
				config[setting] = "%s(%s)" % [value_prefixes[value_types.FLOAT], str(AudioSettings.setting_master_volume)]
			"music_volume":
				config[setting] = "%s(%s)" % [value_prefixes[value_types.FLOAT], str(AudioSettings.setting_music_volume)]
			"effects_volume":
				config[setting] = "%s(%s)" % [value_prefixes[value_types.FLOAT], str(AudioSettings.setting_effects_volume)]
			"voice_volume":
				config[setting] = "%s(%s)" % [value_prefixes[value_types.FLOAT], str(AudioSettings.setting_voice_volume)]
			"full_screen":
				config[setting] = "%s(%s)" % [value_prefixes[value_types.BOOL], str(VideoSettings.fullscreen_enabled)]
			"gui_scale":
				config[setting] = "%s(%s)" % [value_prefixes[value_types.FLOAT], str(VideoSettings.gui_scale)]
	
	return config


func load_sett_config():
	var file = File.new()
	if(file.file_exists(file_name)):
		file.open(file_name,File.READ)
		var file_str = file.get_as_text()
		file.close()
		var data = str2var(file_str)
		if(typeof(data) == TYPE_DICTIONARY):
			setup_settings(data)
		else:
			printerr("corrupted data! " + str(typeof(data)))
	else:
		#NoFile, so lets save the default settings now
		save_settings()
		save_default_settings()


func setup_settings(sett_dict : Dictionary):
	for saved_setting in sett_dict.keys():
		var value = null
		if value_prefixes[0] in sett_dict[saved_setting]:
			value = sett_dict[saved_setting].trim_prefix(value_prefixes[0])
			value = value.trim_prefix("(").trim_suffix(")")
			if "F" in value:
				value = false
			elif "T" in value:
				value = true
			else:
				value = true
		else:
			value = sett_dict[saved_setting].trim_prefix(value_prefixes[1])
			value = value.trim_prefix("(").trim_suffix(")")
			value = value.to_float()
		
		match saved_setting:
			"is_crouch_hold":
				GameSettings.crouch_hold_enabled = value
			"is_ads_hold":
				print("crouch hold = " + str(value))
				print("crouch hold old val = " + str(value))
				GameSettings.ads_hold_enabled = value
				print("crouch hold new val = " + str(value))
			"mouse_sensitivity":
				InputSettings.setting_mouse_sensitivity = value
			"master_volume":
				AudioSettings.setting_master_volume = value
			"music_volume":
				AudioSettings.setting_music_volume = value
			"effects_volume":
				AudioSettings.setting_effects_volume = value
			"voice_volume":
				AudioSettings.setting_voice_volume = value
			"full_screen":
				VideoSettings.fullscreen_enabled = value
			"gui_scale":
				VideoSettings.gui_scale = value


func save_settings():
	var key_dict = gen_dict_from_settings()
	var file = File.new()
	file.open(file_name, File.WRITE)
	file.store_string(var2str(key_dict))
	file.close()
	print("settings config saved")


func save_default_settings():
	var key_dict = gen_dict_from_settings()
	var file = File.new()
	file.open(file_name_default, File.WRITE)
	file.store_string(var2str(key_dict))
	file.close()
	print("settings config saved")
