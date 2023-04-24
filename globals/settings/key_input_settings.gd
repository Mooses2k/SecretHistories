extends Node


const GROUP_NAME : String = "Input Key Settings"

var setting_key_inputs : String = ""
var is_waiting_input : bool = false
var events : PoolStringArray
var actions : PoolStringArray


const MAX_VALUE = 4.0
const STEP_VALUE = 0.05
const MIN_VALUE = 0.05

var setting_action_event : float setget set_action_event, get_action_event


func _ready():
	GlobalSettings.load_keys()
	
	for action in InputMap.get_actions():
		if not "ui_" in action or "movement" == action:
			for event in InputMap.get_action_list(action):
				if event is InputEventMouseButton:
					events.insert(0, "Mouse Button " + str(event.button_index))
	#				print("action " + str(action) + " event mouse == " + str(event.button_index))
				elif event is InputEventJoypadButton:
					events.insert(0, "Joypad Button " + str(event.button_index))
				else:
					if event.physical_scancode:
						events.insert(0, str(OS.get_scancode_string(event.physical_scancode)))
					else:
						events.insert(0, str(OS.get_scancode_string(event.scancode)))
			
			actions.append(action)
			Settings.add_string_setting(action, events)
			Settings.set_setting_group(action, GROUP_NAME)
			events.resize(0)
	
	Settings.connect("setting_changed", self, "on_setting_changed")


func _input(event):
	if event is InputEvent and is_waiting_input:
		print("key pressed " + str(OS.get_scancode_string(event.physical_scancode)))
		pass


func set_action_event(value : float):
	is_waiting_input = true
	Settings.set_setting(setting_key_inputs, value)


func get_action_event() -> float:
	return Settings.get_setting(setting_key_inputs)


func set_event(setting_name, old_value, new_value):
	events.resize(0)
	var events_setting = InputMap.get_action_list(setting_name)
	if events_setting.size() > 1:
		InputMap.action_erase_event(setting_name, events_setting[0])
	InputMap.action_add_event(setting_name, new_value)
	GlobalSettings.save_keys()
	print("successfuly added " + str(new_value) + " to " + setting_name)
	print("\n")
	
	for event in InputMap.get_action_list(setting_name):
		if event is InputEventMouseButton:
			events.insert(0, "Mouse Button " + str(event.button_index))
#				print("action " + str(action) + " event mouse == " + str(event.button_index))
		elif event is InputEventJoypadButton:
			events.insert(0, "Joypad Button " + str(event.button_index))
		else:
			if event.physical_scancode:
				events.insert(0, str(OS.get_scancode_string(event.physical_scancode)))
			else:
				events.insert(0, str(OS.get_scancode_string(event.scancode)))
	
	Settings._settings[setting_name][Settings._FIELD_VALUE] = events
	Settings.emit_signal("keys_saved", setting_name, old_value, events)
	events.resize(0)



func on_setting_changed(setting_name, old_value, new_value):
#	match setting_name:
#		setting_key_inputs:
#			pass
#	pass
	
	if actions.has(setting_name):
		set_event(setting_name, old_value, new_value)
