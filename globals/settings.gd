class_name SettingsClass
extends Node


signal setting_added(setting_name)
signal setting_removed(setting_name)
signal setting_changed(setting_name, old_value, new_value)
signal setting_meta_changed(setting_name)
signal settings_list_changed()

#required fields
const _FIELD_VALUE = "value"
const _FIELD_TYPE = "type"
const _FIELD_DEFAULT = "default"

#optional fields
const _FIELD_GROUP = "group"

#numeric only fields
const _FIELD_MIN = "min_value"
const _FIELD_MAX = "max_value"
const _FIELD_STEP = "step"

#enum only fields
const _FIELD_VARIANTS = "variants"

#UI specifiers
const _CAN_RANDOMIZE_FLAG = "can_randomize"

enum SettingType {
	NIL,
	FLOAT,
	BOOL,
	ENUM,
	INT,
}

# The list of settings as an array of { SettingName : SettingData}
# where each instance of SettingData is a Dictionary containing at least
# the fields 'value', 'type' and 'default'
# SettingData may contain more fields, depending on the specific type,
# and any arbitrary fields that may be necessary for any other purposes
# (like fields that control how the setting is displayed on the settings editor)

var _settings : Dictionary
#var _settings_meta : Dictionary


# Returns an array of all registered setting names
func get_settings_list() -> Array:
	return _settings.keys()


# Returns wether a setting with the given name exists or not
func has_setting(setting_name : String) -> bool:
	return _settings.has(setting_name)


# Returns the value of a setting, or ǹ`null` if the setting doesn't exist
func get_setting(setting_name : String):
	var setting_data = _settings.get(setting_name)
	return setting_data.get(_FIELD_VALUE) if setting_data else null


func set_setting(setting_name : String, value) -> bool:
	if not _settings.has(setting_name):
		return false
	var type = get_setting_type(setting_name)
	match type:
		SettingType.FLOAT, SettingType.INT:
			if (value is float and type == SettingType.FLOAT) or (\
				value is int and type == SettingType.INT):
				var min_value = get_setting_min_value(setting_name)
				var max_value = get_setting_max_value(setting_name)

				# Manual clamp to preserve types
				var new_value = min_value if value < min_value else value
				new_value = max_value if value > max_value else value

				var old_value = _settings[setting_name][_FIELD_VALUE]
				_settings[setting_name][_FIELD_VALUE] = new_value
				emit_signal("setting_changed", setting_name, old_value, new_value)
			else:
				return false
		SettingType.BOOL:
			if value is bool:
				var old_value = _settings[setting_name][_FIELD_VALUE]
				_settings[setting_name][_FIELD_VALUE] = value
				emit_signal("setting_changed", setting_name, old_value, value)
			else:
				return false
		SettingType.ENUM:
			if value is int:
				if value < 0 or value >= (get_setting_variants(setting_name).size()):
					return false
				var old_value = _settings[setting_name][_FIELD_VALUE]
				_settings[setting_name][_FIELD_VALUE] = value
				emit_signal("setting_changed", setting_name, old_value, value)
			else:
				return false
	return true


func get_setting_meta(setting_name : String, meta_name : String):
	var setting_data = _settings.get(setting_name)
	return setting_data.get(meta_name) if setting_data else null


func set_setting_meta(setting_name : String, meta_name : String, meta_value):
	var setting_data = _settings.get(setting_name)
	if not setting_data:
		return
	setting_data[meta_name] = meta_value
	emit_signal("setting_meta_changed", setting_name)


func has_setting_meta(setting_name : String, meta_name : String) -> bool:
	var setting_data = _settings.get(setting_name)
	return setting_data.has(meta_name) if setting_data else false


# Gets the type of a setting, as a variant of the `SettingType` enum
func get_setting_type(setting_name : String) -> int:
	var setting_data = _settings.get(setting_name)
	return setting_data.get(_FIELD_TYPE) if setting_data else SettingType.NIL


# Gets the group a setting belongs to
func get_setting_group(setting_name : String):
	var setting_data = _settings.get(setting_name)
	return setting_data.get(_FIELD_GROUP) if setting_data else null


# Sets the group a setting belongs to
func set_setting_group(setting_name : String, group_name : String):
	var setting_data = _settings.get(setting_name)
	if not setting_data:
		return
	setting_data[_FIELD_GROUP] = group_name
	emit_signal("setting_meta_changed", setting_name)


# Takes a setting out of its group
func clear_setting_group(setting_name : String):
	var setting_data = _settings.get(setting_name)
	if not setting_data:
		return
	setting_data.erase("group")
	emit_signal("setting_meta_changed", setting_name)


# Gets the default value of a setting, or `null` if it doesn't exist
func get_setting_default(setting_name : String):
	var setting_data = _settings.get(setting_name)
	return setting_data.get(_FIELD_DEFAULT) if setting_data else null


# Removes a setting, returns `true` if the setting existed, `false` otherwise
func remove_setting(setting_name : String) -> bool:
	if _settings.erase(setting_name):
		emit_signal("setting_removed", setting_name)
		emit_signal("settings_list_changed")
		return true
	return false


# Add a setting that is a float value. The setting will have the default value.
# Adding will fail if a setting of the same name already exists, returns `true`
# if adding was successful, `false` otherwise
func add_float_setting(setting_name : String, min_value : float, max_value : float, step : float, default : float) -> bool:
	if _settings.has(setting_name):
		return false
	_settings[setting_name] = {
		_FIELD_TYPE : SettingType.FLOAT,
		_FIELD_MIN : min_value,
		_FIELD_MAX : max_value,
		_FIELD_STEP : step,
		_FIELD_DEFAULT : default,
		_FIELD_VALUE : default
	}
	emit_signal("setting_added", setting_name)
	emit_signal("settings_list_changed")
	return true


func is_setting_float(setting_name : String) -> bool:
	return get_setting_type(setting_name) == SettingType.FLOAT


# Add a setting that is an int value. The setting will have the default value.
# Adding will fail if a setting of the same name already exists, returns `true`
# if adding was successful, `false` otherwise
func add_int_setting(setting_name : String, min_value : int, max_value : int, step : int, default : int) -> bool:
	if _settings.has(setting_name):
		return false
	_settings[setting_name] = {
		_FIELD_TYPE : SettingType.INT,
		_FIELD_MIN : min_value,
		_FIELD_MAX : max_value,
		_FIELD_STEP : step,
		_FIELD_DEFAULT : default,
		_FIELD_VALUE : default
	}
	emit_signal("setting_added", setting_name)
	emit_signal("settings_list_changed")
	return true


func is_setting_int(setting_name : String) -> bool:
	return get_setting_type(setting_name) == SettingType.INT


func get_setting_min_value(setting_name : String):
	var setting_data = _settings.get(setting_name)
	return setting_data.get(_FIELD_MIN) if setting_data else null


func set_setting_min_value(setting_name : String, min_value):
	var setting_data = _settings.get(setting_name)
	if not setting_data:
		return
	var setting_type = setting_data[_FIELD_TYPE]
	if (setting_type == SettingType.FLOAT and not min_value is float):
		printerr("Setting '", setting_name, "' has type float, but the given min value ", min_value, " has a different type")
		return
	if (setting_type == SettingType.INT and not min_value is int):
		printerr("Setting '", setting_name, "' has type int, but the given min value ", min_value, " has a different type")
		return
	setting_data[_FIELD_MIN] = min_value


func get_setting_max_value(setting_name : String):
	var setting_data = _settings.get(setting_name)
	return setting_data.get(_FIELD_MAX) if setting_data else null


func set_setting_max_value(setting_name : String, max_value):
	var setting_data = _settings.get(setting_name)
	if not setting_data:
		return
	var setting_type = setting_data[_FIELD_TYPE]
	if (setting_type == SettingType.FLOAT and not max_value is float):
		printerr("Setting '", setting_name, "' has type float, but the given max value ", max_value, " has a different type")
		return
	if (setting_type == SettingType.INT and not max_value is int):
		printerr("Setting '", setting_name, "' has type int, but the given max value ", max_value, " has a different type")
		return
	setting_data[_FIELD_MAX] = max_value


func get_setting_step(setting_name : String):
	var setting_data = _settings.get(setting_name)
	return setting_data.get(_FIELD_STEP) if setting_data else null


func set_setting_step(setting_name : String, step):
	var setting_data = _settings.get(setting_name)
	if not setting_data:
		return
	var setting_type = setting_data[_FIELD_TYPE]
	if (setting_type == SettingType.FLOAT and not step is float):
		printerr("Setting '", setting_name, "' has type float, but the given step value ", step, " has a different type")
		return
	if (setting_type == SettingType.INT and not step is int):
		printerr("Setting '", setting_name, "' has type int, but the given step value ", step, " has a different type")
		return
	setting_data[_FIELD_STEP] = step


# Add a setting that is a bool value. The setting will have the default value.
# Adding will fail if a setting of the same name already exists, returns `true`
# if adding was successful, `false` otherwise
func add_bool_setting(setting_name : String, default : bool) -> bool:
	if _settings.has(setting_name):
		return false
	_settings[setting_name] = {
		_FIELD_TYPE : SettingType.BOOL,
		_FIELD_DEFAULT : default,
		_FIELD_VALUE : default
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
func add_enum_setting(setting_name : String, variants : PoolStringArray, default : int) -> bool:
	if _settings.has(setting_name) or default > variants.size() - 1 or default < 0:
		return false
	_settings[setting_name] = {
		_FIELD_TYPE : SettingType.ENUM,
		_FIELD_VARIANTS : variants,
		_FIELD_DEFAULT : default,
		_FIELD_VALUE : default
	}
	emit_signal("setting_added", setting_name)
	emit_signal("settings_list_changed")
	return true


func get_setting_variants(setting_name : String) -> PoolStringArray:
	var setting_data = _settings.get(setting_name)
	var variants = setting_data.get(_FIELD_VARIANTS)
	return variants if variants is PoolStringArray else PoolStringArray()


func is_setting_enum(setting_name : String) -> bool:
	return get_setting_type(setting_name) == SettingType.ENUM
