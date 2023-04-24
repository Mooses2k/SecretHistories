extends "SettingEditor.gd"

var is_waiting_input : bool = false


#Override this function
func _get_value():
	return str($"%Value".text)
	pass


#Override this function
func _set_value(value):
	$"%Value".text = ""
	for event in value:
		$"%Value".text += event
		if value.find(event) != (value.size() - 1):
			$"%Value".text += ", "
#	if value.physical_scancode:
#		$"%Value".text = str(OS.get_scancode_string(value.physical_scancode))
#	else:
#		$"%Value".text = str(OS.get_scancode_string(value.scancode))


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


func _on_Value_value_changed(value):
	on_value_edited()


func _input(event):
	if is_waiting_input:
		if not event is InputEventMouseMotion:
			if event is InputEventMouseButton:
				print("Mouse Button " + str(event.get_button_index()))
			elif event is InputEventJoypadButton:
				print("Joypad Button " + str(event.get_button_index()))
			elif event is InputEventJoypadMotion:
				print("Joypad Motion " + str(event.get_axis()))
			elif event is InputEventKey:
				if event.physical_scancode:
					if event.physical_scancode == 16777217:
						return
				else:
					if event.scancode == 16777217:
						return
				print(str(OS.get_scancode_string(event.physical_scancode)))
			
			get_parent().get_parent().get_parent().get_parent().owner.get_node("Panel").hide()
			is_waiting_input = false
			settings.set_setting(_setting_name, event)
#			find_scancode_from_string


func _on_TextEdit_pressed():
	get_parent().get_parent().get_parent().get_parent().owner.get_node("Panel").show()
	is_waiting_input = true
	
