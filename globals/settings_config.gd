extends Node

var game_manager : GDScript = preload("res://globals/game_manager.gd")

var file_name = "%s://globals/settings/settingsConfig.dict" % ("user" if OS.has_feature("standalone") else "res")
var file_name_default = "%s://globals/settings/defaultSettConfig.dict" % ("user" if OS.has_feature("standalone") else "res")

var setting_key = false

enum sett_value_types {
	BOOL,
	FLOAT
}

var value_sett_prefixes = [
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
	var value_type = sett_value_types.BOOL
	for setting in game_manager.get_script_property_list():
		if setting.name in settings_names:
			if setting.type == 1:
				value_type = sett_value_types.BOOL
			elif setting.type == 3:
				value_type = sett_value_types.FLOAT
			config[setting.name] = "%s(%s)" % [value_sett_prefixes[value_type], str(GameManager[setting.name])]
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
		for setting in game_manager.get_script_property_list():
			if saved_setting == setting.name:
				var value
				if value_sett_prefixes[0] in sett_dict[saved_setting]:
					value = sett_dict[saved_setting].trim_prefix(value_sett_prefixes[0])
					value = value.trim_prefix("(").trim_suffix(")")
					if value == "False":
						value = false
					elif value == "True":
						value = true
					else:
						value = true
				else:
					value = sett_dict[saved_setting].trim_prefix(value_sett_prefixes[1])
					value = value.trim_prefix("(").trim_suffix(")")
					value = value.to_float()
				GameManager[setting.name] = value


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
