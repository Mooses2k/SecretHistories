extends "setting_editor.gd"


#Override this function
func _get_value():
	return int(%Value.value)


#Override this function
func _set_value(value):
	%Value.value = value


#Override this function
func _on_value_edited():
	var new_value = get_value()
	if new_value != settings.get_setting(_setting_name):
		settings.set_setting(_setting_name, new_value)


#Override this function
func _on_setting_attached():
	%Value.min_value = settings.get_setting_min_value(_setting_name)
	%Value.max_value = settings.get_setting_max_value(_setting_name)
	%Value.step = settings.get_setting_step(_setting_name)
#	%Value.connect("value_changed", self, "on_value_edited")
	_apply_name_text()
	_apply_name_tooltip()
	%RandomizeButton.visible = settings.has_setting_meta(_setting_name, settings._CAN_RANDOMIZE_FLAG)


## A setting can carry a display_name meta for the label, so its key can stay
## a machine-readable identifier. Without one, fall back to the key text and
## the existing group|label pipe convention.
func _apply_name_text():
	var display_name = settings.get_setting_meta(_setting_name, "display_name")
	if display_name is String and not display_name.is_empty():
		%Name.text = display_name
	elif _setting_name.contains('|'):
		%Name.text = _setting_name.split('|')[1]
	else:
		%Name.text = _setting_name


## Settings that reference a scene or resource carry its path as the
## full_path meta: show it as a tooltip instead of stretching the label
func _apply_name_tooltip():
	var full_path = settings.get_setting_meta(_setting_name, "full_path")
	if full_path is String and not full_path.is_empty():
		%Name.tooltip_text = full_path


func _on_Value_value_changed(value):
	on_value_edited()


func _on_RandomizeButton_pressed() -> void:
	var random_value = wrapi(randi()*%Value.step + %Value.min_value, %Value.min_value, %Value.max_value + 1)
	settings.set_setting(_setting_name, random_value)
