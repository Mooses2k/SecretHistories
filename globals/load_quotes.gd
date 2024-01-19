extends Node


@onready var file1 = 'res://resources/text/loadscreen_quotes/list1.txt' # text files on 'resources' folder
@onready var file2 = 'res://resources/text/loadscreen_quotes/list2.txt' # creepier list for Acts 3+

var list1 : PackedStringArray
var list2 : PackedStringArray
var temp
var keys = ""


func check_word():
	if "[Interact key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("player|interact"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Interact key]", keys)
		return true

	elif "[Move_right key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("movement|move_right"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Move_right key]", keys)
		return true

	elif "[Move_left key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("movement|move_left"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Move_left key]", keys)
		return true

	elif "[Move_up key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("movement|move_up"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Move_up key]", keys)
		return true

	elif "[Move_down key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("movement|move_down"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Move_down key]", keys)
		return true

	elif "[Sprint key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("player|sprint"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Sprint key]", keys)
		return true

	elif "[Melee key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("player|kick"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Melee key]", keys)
		return true

	elif "[Reload key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("player|reload"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Reload key]", keys)
		return true

	elif "[Off-hand use key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("playerhand|offhand_use"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Off-hand use key]", keys)
		return true

	elif "[Off-hand switch key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("playerhand|cycle_offhand_slot"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Off-hand switch key]", keys)
		return true

	elif "[Off-hand throw key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("playerhand|offhand_throw"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Off-hand throw key]", keys)
		return true

	elif "[Main-hand throw key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("playerhand|main_throw"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Main-hand throw key]", keys)
		return true

	elif "[Main-hand use key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("playerhand|main_use_primary"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Main-hand use key]", keys)
		check_word()
		return

	elif "[Main-hand secondary key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("playerhand|main_use_secondary"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Main-hand secondary key]", keys)
		return true

	elif "[Map key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("misc|map_menu"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Map key]", keys)
		return true

	elif "[Binoculars key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("ablty|binocs_spyglass"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Binoculars key]", keys)
		return true

	elif "[Change look key]" in temp:
		keys = ""
		for actionKey in InputMap.action_get_events("misc|change_screen_filter"):
			if actionKey is InputEventKey:
				if not keys.is_empty():
					keys += " or "
				keys += OS.get_keycode_string(actionKey.keycode)
		temp = temp.replace("[Change look key]", keys)
		return true

	elif "[" in temp:
		printerr(temp) # this will catch wrong writing in list and mouse events (not implemented)

	return false


func load_files():
	var f = FileAccess.open(file1, FileAccess.READ)
	while not f.eof_reached(): # iterate through all lines until the end of file is reached
		temp = f.get_line()
		if not temp == "":
			while check_word():
				pass
			list1.append(temp)
			print(temp)
	f.close()

	f = FileAccess.open(file2, FileAccess.READ)
	while not f.eof_reached(): # iterate through all lines until the end of file is reached
		temp = f.get_line()
		if not temp == "":
			list2.append(temp)
	f.close()
	return
