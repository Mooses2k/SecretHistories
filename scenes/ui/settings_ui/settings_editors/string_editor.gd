extends "setting_editor.gd"


var is_waiting_input : bool = false
var temp_setting_name : String = ""


# Override this function
func _get_value():
	return str(%Value.text)


# Override this function
func _set_value(value):
	%Value.text = ""
	if value == null:
		return
	
	for event in value:
		var temp_event = event
		match event:
			"Mouse Button 1":
				temp_event = "Mouse Left Button"
			"Mouse Button 2":
				temp_event = "Mouse Right Button"
			"Mouse Button 3":
				temp_event = "Mouse Middle Button"
			"Mouse Button 4":
				temp_event = "Mouse Wheel Up"
			"Mouse Button 5":
				temp_event = "Mouse Wheel Down"
		%Value.text += temp_event
		if value.find(event) != (value.size() - 1):
			%Value.text += ", "


# Override this function
func _on_value_edited():
	var new_value = get_value()
	if new_value != settings.get_setting(_setting_name):
		settings.set_setting(_setting_name, new_value)


# Override this function
func _on_setting_attached():
#	%Value.connect("value_changed", self, "on_value_edited")
	temp_setting_name = _setting_name
	
	if "movement|" in temp_setting_name:
		temp_setting_name.erase(0, 9)
		
	elif "player|" in temp_setting_name:
		temp_setting_name.erase(0, 7)
		
	elif "playerhand|" in temp_setting_name:
		temp_setting_name.erase(0, 11)
		
	elif "misc|" in temp_setting_name:
		temp_setting_name.erase(0, 5)
		
	elif "itm|" in temp_setting_name:
		temp_setting_name.erase(0, 4)
		
	elif "ablty|" in temp_setting_name:
		temp_setting_name.erase(0, 6)
		
	elif "com|" in temp_setting_name:
		temp_setting_name.erase(0, 4)
	
	temp_setting_name = temp_setting_name.replace("_", " ")
	%Name.text = temp_setting_name[0].to_upper() + temp_setting_name.substr(1,-1)


func _on_Value_value_changed(value):
	on_value_edited()


func _input(event):
	var change_key_panel = _find_change_key_panel()
	if change_key_panel and not change_key_panel.visible:
		is_waiting_input = false
		
	if is_waiting_input:
		if not event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()
			
			if event is InputEventMouseButton:
				print("Mouse Button " + str(event.get_button_index()))
				if event.get_button_index() == 2:
						return
			elif event is InputEventJoypadButton:
				print("Joypad Button " + str(event.get_button_index()))
			elif event is InputEventJoypadMotion:
				print("Joypad Motion " + str(event.get_axis()))
			elif event is InputEventKey:
				if event.physical_keycode:
					if event.physical_keycode == 16777217:
						return
				else:
					if event.keycode == 16777217:
						return
				print(str(OS.get_keycode_string(event.physical_keycode)))
			
			if change_key_panel:
				change_key_panel.hide()
			is_waiting_input = false
			settings.set_setting(_setting_name, event)


func _on_Clear_pressed():
	settings.set_setting(_setting_name, null)


func _find_change_key_panel():
	# Try to find the ChangeKeyPanel by traversing up the node tree safely
	var current_node = self
	var max_depth = 10  # Prevent infinite loops
	var depth = 0
	
	while current_node and depth < max_depth:
		# Check if current node has ChangeKeyPanel as a child
		var change_key_panel = current_node.get_node_or_null("ChangeKeyPanel")
		if change_key_panel:
			return change_key_panel
		
		# Check if current node has an owner with ChangeKeyPanel
		if current_node.owner:
			change_key_panel = current_node.owner.get_node_or_null("ChangeKeyPanel")
			if change_key_panel:
				return change_key_panel
		
		# Move up to parent
		current_node = current_node.get_parent()
		depth += 1
	
	# If not found, try to find it in the scene tree
	var scene_root = get_tree().current_scene
	if scene_root:
		return scene_root.find_child("ChangeKeyPanel", true, false)
	
	return null

func _on_Change_pressed():
	var change_key_panel = _find_change_key_panel()
	if change_key_panel:
		change_key_panel.show()
	is_waiting_input = true
