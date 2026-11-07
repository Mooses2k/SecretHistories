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
		%Value.text += event
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
	_apply_name_text()


## A keybinding row carries a display_name meta from the declarative map.
## Without one, fall back to the text after the action's namespace pipe, or
## the raw name for pipe-less actions like hotbar_1.
func _apply_name_text():
	var display_name = settings.get_setting_meta(_setting_name, "display_name")
	if display_name is String and not display_name.is_empty():
		%Name.text = display_name
	elif _setting_name.contains('|'):
		%Name.text = _setting_name.get_slice('|', 1).capitalize()
	else:
		%Name.text = _setting_name.capitalize()


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


## Helper function to find the ChangeKeyPanel node robustly
func _find_change_key_panel() -> Control:
	# First try to find it in the scene tree by name
	var scene_root = get_tree().current_scene
	if scene_root:
		var panel = scene_root.find_child("ChangeKeyPanel", true, false)
		if panel:
			return panel
	
	# Fallback: traverse up the tree looking for a node with ChangeKeyPanel
	var current_node = self
	while current_node:
		if current_node.has_node("ChangeKeyPanel"):
			return current_node.get_node("ChangeKeyPanel")
		current_node = current_node.get_parent()
	
	return null


func _on_Clear_pressed():
	settings.set_setting(_setting_name, null)


func _on_Change_pressed():
	var change_key_panel = _find_change_key_panel()
	if change_key_panel:
		change_key_panel.show()
		is_waiting_input = true
	else:
		print("Warning: ChangeKeyPanel not found")
