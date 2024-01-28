extends Node


@export var _setting_type : int = SettingsClass.SettingType.NIL # (SettingsClass.SettingType)
var _setting_name : String
var settings : SettingsClass


#Override this function
func _get_value():
	pass


#Override this function
func _set_value(value):
	pass


#Override this function
func _on_value_edited():
	pass


#Override this function
func _on_setting_attached():
	pass


func get_value():
	return _get_value()


func set_value(value):
	_set_value(value)


func attach_setting(setting_name : String, _settings : SettingsClass):
	settings = _settings
	if not settings.has_setting(setting_name):
		printerr("settings controller at ", settings.get_path(), " lacks setting ", setting_name)
	if not settings.get_setting_type(setting_name) == _setting_type:
		printerr("settings controller at ", settings.get_path(), " has setting ", setting_name, "\n",\
		"But the type doesn't match: real = ", settings.get_setting_type(setting_name), " expected :", _setting_type)
	_setting_name = setting_name
	settings.connect("setting_changed", Callable(self, "on_setting_changed"))
	settings.connect("setting_removed", Callable(self, "on_setting_removed"))
	settings.connect("keys_saved", Callable(self, "on_setting_changed"))
	_on_setting_attached()
	set_value(settings.get_setting(setting_name))


func on_setting_changed(setting_name, old_value, new_value):
	if setting_name == _setting_name:
		if new_value is String and new_value == "all":
			return
		_on_setting_changed(old_value, new_value)


func _on_setting_changed(old_value, new_value):
	if get_value() is String:
		if not new_value is InputEvent:
			set_value(new_value)
	else:
		if new_value != get_value():
			set_value(new_value)


func on_setting_removed(setting_name):
	if setting_name == _setting_name:
		_on_setting_removed()


func _on_setting_removed():
	queue_free()


func on_value_edited():
	_on_value_edited()
