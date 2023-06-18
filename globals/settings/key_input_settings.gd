extends Node


const GROUP_NAME : String = "Input Key Settings"

var setting_key_inputs : String = ""
var is_waiting_input : bool = false
var events : PoolStringArray = []
var actions : PoolStringArray = []
var actions_copy : PoolStringArray
var flag : int = 1
var index : int = 0
var is_done : bool = false
var key_removed : bool = false
var hotbar_num : int = 1
var arr_size : int = 0
var counter : int = 0

const MAX_VALUE = 4.0
const STEP_VALUE = 0.05
const MIN_VALUE = 0.05

var setting_action_event : float setget set_action_event, get_action_event


func _ready():
	actions_copy.append_array(InputMap.get_actions())
	
	while not is_done:
		counter += 1
		key_removed = false
		arr_size = actions_copy.size()
		index = -1
		
		for x in range(arr_size):
			if not "ui_" in actions_copy[x] or "movement" == actions_copy[x]:
				match flag:
					1:
						if "movement|" in actions_copy[x]:
							set_keys(x)
					2:
						if "player|" in actions_copy[x]:
							set_keys(x)
					3:
						if "playerhand|" in actions_copy[x]:
							set_keys(x)
					4:
						if "misc|" in actions_copy[x]:
							set_keys(x)
					5:
						if "hotbar_" in actions_copy[x]:
							if str(hotbar_num) in actions_copy[x] and hotbar_num < 11:
								set_keys(x)
								hotbar_num += 1
					_:
						actions_copy.remove(actions_copy.find(actions_copy[x]))
						key_removed = true
			else:
				actions_copy.remove(actions_copy.find(actions_copy[x]))
				key_removed = true
			
			index = x
			if key_removed:
				break
			
		
		if index == arr_size - 1: 
			flag += 1
			
			if flag == 6 and not hotbar_num == 11:
				flag = 5
		
		if actions_copy.size() < 1 or counter > 100:
			is_done = true
		
	Settings.connect("setting_changed", self, "on_setting_changed")


func set_keys(x):
	for event in InputMap.get_action_list(actions_copy[x]):
		if event is InputEventMouseButton:
			events.insert(0, "Mouse Button " + str(event.button_index))
		elif event is InputEventJoypadButton:
			events.insert(0, "Joypad Button " + str(event.button_index))
		else:
			if event.physical_scancode:
				events.insert(0, str(OS.get_scancode_string(event.physical_scancode)))
			else:
				events.insert(0, str(OS.get_scancode_string(event.scancode)))
	
	actions.append(actions_copy[x])
	Settings.add_string_setting(actions_copy[x], events)
	Settings.set_setting_group(actions_copy[x], GROUP_NAME)
	actions_copy.remove(actions_copy.find(actions_copy[x]))
	events.resize(0)
	key_removed = true


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
	if new_value == null:
		InputMap.action_erase_events(setting_name)
	else:
		var events_setting = InputMap.get_action_list(setting_name)
		if events_setting.size() > 1:
			InputMap.action_erase_event(setting_name, events_setting[0])
		InputMap.action_add_event(setting_name, new_value)
	
	GlobalSettings.save_keys()
	events.resize(0)
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
