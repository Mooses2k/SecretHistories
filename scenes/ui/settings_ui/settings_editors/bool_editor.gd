extends "setting_editor.gd"


#Override this function
func _get_value():
	return $"%Value".pressed
	pass


#Override this function
func _set_value(value):
	$"%Value".pressed = value
	pass


#Override this function
func _on_value_edited():
	var new_value = get_value()
	if new_value != settings.get_setting(_setting_name):
		settings.set_setting(_setting_name, new_value)
	pass


#Override this function
func _on_setting_attached():
#	$"%Value".connect("value_changed", self, "on_value_edited")
	$"%Name".text = _setting_name
	pass


func _on_Value_toggled(button_pressed):
	on_value_edited()
	pass # Replace with function body.
