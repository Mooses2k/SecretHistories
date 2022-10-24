extends Node
class_name SettingsClass


signal setting_added(setting_name)
signal setting_removed(setting_name)
signal setting_changed(setting_name, old_value, new_value)
signal setting_meta_changed(setting_name)
signal settings_list_changed()

var _settings : Dictionary
var _settings_meta : Dictionary

enum SettingType {
	FLOAT,
	BOOL,
	ENUM,
	NIL
}


func get_settings_list() -> Array:
	return _settings.keys()


func has_setting(setting_name : String) -> bool:
	return _settings.has(setting_name)


# Gets the value of a setting, or ǹ`null` if it doesn't exist
func get_setting(setting_name : String):
	return _settings.get(setting_name)


func set_setting(setting_name : String, value) -> bool:
	if not _settings.has(setting_name):
		return false
	var type = get_setting_type(setting_name)
	match type:
		SettingType.FLOAT:
			if value is float:
				var min_value = get_float_setting_min_value(setting_name)
				var max_value = get_float_setting_max_value(setting_name)
				var new_value = clamp(value, min_value, max_value)
				var old_value = _settings[setting_name]
				_settings[setting_name] = new_value
				emit_signal("setting_changed", setting_name, old_value, new_value)
			else:
				return false
		SettingType.BOOL:
			if value is bool:
				var old_value = _settings[setting_name]
				_settings[setting_name] = value
				emit_signal("setting_changed", setting_name, old_value, value)
			else:
				return false
		SettingType.ENUM:
			if value is int:
				if value < 0 or value > (get_enum_setting_values(setting_name).size() - 1):
					return false
				var old_value = _settings[setting_name]
				_settings[setting_name] = value
				emit_signal("setting_changed", setting_name, old_value, value)
			else:
				return false
	return true


# Gets the type of a setting, as a variant of the `SettingType` enum
func get_setting_type(setting_name : String) -> int:
	if _settings_meta.has(setting_name):
		return _settings_meta[setting_name].type
	return SettingType.NIL


# Gets the group a setting belongs to
func get_setting_group(setting_name : String):
	if not _settings.has(setting_name):
		return null
	return (_settings_meta[setting_name] as Dictionary).get("group")


# Sets the group a setting belongs to
func set_setting_group(setting_name : String, group_name : String):
	if not _settings.has(setting_name):
		return
	(_settings_meta[setting_name] as Dictionary)["group"] = group_name
	emit_signal("setting_meta_changed", setting_name)


# Takes a setting out of its group
func clear_setting_group(setting_name : String):
	if not _settings.has(setting_name):
		return null
	(_settings_meta[setting_name] as Dictionary).erase("group")
	emit_signal("setting_meta_changed", setting_name)


# Gets the default value of a setting, or `null` if it doesn't exist
func get_setting_default(setting_name : String):
	if _settings_meta.has(setting_name):
		return (_settings_meta[setting_name] as Dictionary).get("default")
	return null


# Removes a setting, returns `true` if the setting existed, `false` otherwise
func remove_setting(setting_name : String) -> bool:
	_settings_meta.erase(setting_name)
	return _settings.erase(setting_name)
	emit_signal("setting_removed", setting_name)
	emit_signal("settings_list_changed")


# Add a setting that is a float value. The setting will have the default value.
# Adding will fail if a setting of the same name already exists, returns `true`
# if adding was successful, `false` otherwise
func add_float_setting(setting_name : String, min_value : float, max_value : float, step : float, default : float) -> bool:
	if _settings.has(setting_name):
		return false
	_settings[setting_name] = default
	_settings_meta[setting_name] = {
		type = SettingType.FLOAT,
		min_value = min_value,
		max_value = max_value,
		step = step,
		default = default,
	}
	emit_signal("setting_added", setting_name)
	emit_signal("settings_list_changed")
	return true


func get_float_setting_min_value(setting_name : String) -> float:
	if _settings_meta.has(setting_name):
		return _settings_meta[setting_name].get("min_value")
	return 0.0


func get_float_setting_max_value(setting_name : String) -> float:
	if _settings_meta.has(setting_name):
		return _settings_meta[setting_name].get("max_value")
	return 0.0


func get_float_setting_step(setting_name : String) -> float:
	if _settings_meta.has(setting_name):
		return _settings_meta[setting_name].get("step")
	return 0.0


func is_setting_float(setting_name : String) -> bool:
	return get_setting_type(setting_name) == SettingType.FLOAT


# Add a setting that is a bool value. The setting will have the default value.
# Adding will fail if a setting of the same name already exists, returns `true`
# if adding was successful, `false` otherwise
func add_bool_setting(setting_name : String, default : bool) -> bool:
	if _settings.has(setting_name):
		return false
	_settings[setting_name] = default
	_settings_meta[setting_name] = {
		type = SettingType.BOOL,
		default = default,
	}
	emit_signal("setting_added", setting_name)
	emit_signal("settings_list_changed")
	return true


func is_setting_bool(setting_name : String) -> bool:
	return get_setting_type(setting_name) == SettingType.BOOL


# Add a setting that is a enum value. The setting will have the default value.
# Adding will fail if a setting of the same name already exists, returns `true`
# if adding was successful, `false` otherwise
# Note that the value of the setting itself is an int, that indicates an entry
# in the list of possible values
func add_enum_setting(setting_name : String, values : PoolStringArray, default : int) -> bool:
	if _settings.has(setting_name) or default > values.size() - 1:
		return false
	_settings[setting_name] = default
	_settings_meta[setting_name] = {
		type = SettingType.ENUM,
		values = values,
		default = default
	}
	emit_signal("setting_added", setting_name)
	emit_signal("settings_list_changed")
	return true


func get_enum_setting_values(setting_name : String) -> PoolStringArray:
	if _settings_meta.has(setting_name):
		return _settings_meta[setting_name].get("values")
	return PoolStringArray()


func is_setting_enum(setting_name : String) -> bool:
	return get_setting_type(setting_name) == SettingType.ENUM
