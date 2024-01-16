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
var arr_size : int = 0
var safe_counter : int = 0
var counter : int = 0
var counter_max : int = 0

const MAX_VALUE = 4.0
const STEP_VALUE = 0.05
const MIN_VALUE = 0.05

var setting_action_event : float setget set_action_event, get_action_event


func _ready():
	actions_copy.append_array(InputMap.get_actions())
	
	while not is_done:
		safe_counter += 1
		key_removed = false
		arr_size = actions_copy.size()
		index = -1
		
		for x in range(arr_size):
			if not "ui_" in actions_copy[x] or "movement" == actions_copy[x] or not "debug_" in actions_copy[x]:
				match flag:
					1:
						if "movement|" in actions_copy[x]:
							if "move_up" in actions_copy[x] and counter == 0:
								set_keys(x)
							elif "move_left" in actions_copy[x] and counter == 1:
								set_keys(x)
							elif "move_right" in actions_copy[x] and counter == 2:
								set_keys(x)
							elif "move_down" in actions_copy[x] and counter == 3:
								set_keys(x)
					2:
						if "player|" in actions_copy[x]:
							if "interact" in actions_copy[x] and counter == 0:
								set_keys(x)
							elif "reload" in actions_copy[x] and counter == 1:
								set_keys(x)
							elif "kick" in actions_copy[x] and counter == 2:
								set_keys(x)
							elif "jump" in actions_copy[x] and counter == 3:
								set_keys(x)
							elif "crouch" in actions_copy[x] and counter == 4:
								set_keys(x)
							elif "sprint" in actions_copy[x] and counter == 5:
								set_keys(x)
					3:
						if "playerhand|" in actions_copy[x]:
							if "main_use_primary" in actions_copy[x] and counter == 0:
								set_keys(x)
							elif "main_use_secondary" in actions_copy[x] and counter == 1:
								set_keys(x)
							elif "main_throw" in actions_copy[x] and counter == 2:
								set_keys(x)
							elif "offhand_use" in actions_copy[x] and counter == 3:
								set_keys(x)
							elif "offhand_throw" in actions_copy[x] and counter == 4:
								set_keys(x)
							elif "cycle_offhand_slot" in actions_copy[x] and counter == 5:
								set_keys(x)
					4:
						if "itm|" in actions_copy[x]:
							if "next_hotbar_item" in actions_copy[x] and counter == 0:
								set_keys(x)
							elif "previous_hotbar_item" in actions_copy[x] and counter == 1:
								set_keys(x)
							elif "holster_offhand" in actions_copy[x] and counter == 2:
								set_keys(x)
					5:
						if "hotbar_" in actions_copy[x]:
							if str(counter + 1) in actions_copy[x] and counter < 10:
								if (counter + 1) == 1 and ( "11" in actions_copy[x] or "10" in actions_copy[x]):
									pass
								else:
									set_keys(x)
					6:
						if "ablty|" in actions_copy[x]:
							if "binocs_spyglass" in actions_copy[x] and counter == 0:
								set_keys(x)
							elif "nightvision_darksight" in actions_copy[x] and counter == 1:
								set_keys(x)
							elif "zap_spell" in actions_copy[x] and counter == 2:
								set_keys(x)
					7:
						if "com|" in actions_copy[x]:
							if "communication_stop" in actions_copy[x] and counter == 0:
								set_keys(x)
							elif "communication_go" in actions_copy[x] and counter == 1:
								set_keys(x)
							elif "communication_text" in actions_copy[x] and counter == 2:
								set_keys(x)
					8:
						if "misc|" in actions_copy[x]:
							if "inventory_menu" in actions_copy[x] and counter == 0:
								set_keys(x)
							elif "journal" in actions_copy[x] and counter == 1:
								set_keys(x)
							elif "map_menu" in actions_copy[x] and counter == 2:
								set_keys(x)
							elif "help_info" in actions_copy[x] and counter == 3:
								set_keys(x)
							elif "fullscreen" in actions_copy[x] and counter == 4:
								set_keys(x)
							elif "change_screen_filter" in actions_copy[x] and counter == 5:
								set_keys(x)
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
			if counter == counter_max:
				flag += 1
				counter = 0
			
			match flag:
				1:
					counter_max = 4
				2:
					counter_max = 6
				3:
					counter_max = 6
				4:
					counter_max = 3
				5:
					counter_max = 10
				6:
					counter_max = 3
				7:
					counter_max = 3
				8:
					counter_max = 6
		
		if actions_copy.size() < 1 or safe_counter > 100:
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
	counter += 1


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
	
	KeybindingManager.save_keys()
	
	save_keys(setting_name, old_value)


func save_keys(setting_name : String, old_value):
	events.resize(0)
	for event in InputMap.get_action_list(setting_name):
		if event is InputEventMouseButton:
			events.insert(0, "Mouse Button " + str(event.button_index))
		elif event is InputEventJoypadButton:
			events.insert(0, "Joypad Button " + str(event.button_index))
		else:
			if event.physical_scancode:
				events.insert(0, str(OS.get_scancode_string(event.physical_scancode)))
			else:
				events.insert(0, str(OS.get_scancode_string(event.scancode)))
	
	if old_value == null:
		old_value = Settings._settings[setting_name][Settings._FIELD_VALUE]
	
	Settings._settings[setting_name][Settings._FIELD_VALUE] = events
	Settings.emit_signal("keys_saved", setting_name, old_value, events)
	events.resize(0)


func on_setting_changed(setting_name, old_value, new_value):
	if new_value is String and new_value == "all":
		reset_actions()
	elif actions.has(setting_name):
		set_event(setting_name, old_value, new_value)


func reset_actions():
	for action in actions:
		InputMap.action_erase_events(action)
		
		var has_invalid : bool = false
		var events_arr = Array()
		for event_str in KeybindingManager.keys_default[action]:
			var event = KeybindingManager.str2event(event_str)
			if event:
				events_arr.push_back(event)
			else:
				has_invalid = true
		if not has_invalid:
			InputMap.action_erase_events(action)
		for event in events_arr:
			InputMap.action_add_event(action, event)
		
		save_keys(action, null)
	
	KeybindingManager.save_keys()
