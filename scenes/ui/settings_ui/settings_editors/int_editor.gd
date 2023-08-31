extends "setting_editor.gd"


#Override this function
func _get_value():
	return int($"%Value".value)
	pass


#Override this function
func _set_value(value):
	$"%Value".value = value
	pass


#Override this function
func _on_value_edited():
	var new_value = get_value()
	if new_value != settings.get_setting(_setting_name):
		settings.set_setting(_setting_name, new_value)
	pass


#Override this function
func _on_setting_attached():
	$"%Value".min_value = settings.get_setting_min_value(_setting_name)
	$"%Value".max_value = settings.get_setting_max_value(_setting_name)
	$"%Value".step = settings.get_setting_step(_setting_name)
#	$"%Value".connect("value_changed", self, "on_value_edited")
	$"%Name".text = _setting_name
	$"%RandomizeButton".visible = settings.has_setting_meta(_setting_name, settings._CAN_RANDOMIZE_FLAG)
	pass


func _on_Value_value_changed(value):
	on_value_edited()


func _on_RandomizeButton_pressed() -> void:
	var random_value = wrapi(randi()*$"%Value".step + $"%Value".min_value, $"%Value".min_value, $"%Value".max_value + 1)
	settings.set_setting(_setting_name, random_value)
