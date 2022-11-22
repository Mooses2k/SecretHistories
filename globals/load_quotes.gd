extends Node


onready var file1 = 'res://resources/list1.txt' # text files on 'resources' folder
onready var file2 = 'res://resources/list2.txt' # creepier list for Acts 3+

var list1 : PoolStringArray
var list2 : PoolStringArray
var temp
var keys = ""


func check_word():
	if "[Interact key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("interact"):
			if actionKey is InputEventKey:
				if not keys.empty():
					keys += " or "
				keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Interact key]", keys)
		return true

	elif "[Move_right key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("move_right"):
			if actionKey is InputEventKey:
				if not keys.empty():
					keys += " or "
				keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Move_right key]", keys)
		return true

	elif "[Move_left key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("move_left"):
			if actionKey is InputEventKey:
				if not keys.empty():
					keys += " or "
				keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Move_left key]", keys)
		return true

	elif "[Move_up key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("move_up"):
			if actionKey is InputEventKey:
				if not keys.empty():
					keys += " or "
				keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Move_up key]", keys)
		return true

	elif "[Move_down key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("move_down"):
			if actionKey is InputEventKey:
				if not keys.empty():
					keys += " or "
				keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Move_down key]", keys)
		return true

	elif "[Sprint key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("sprint"):
			if actionKey is InputEventKey:
				if not keys.empty():
					keys += " or "
				keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Sprint key]", keys)
		return true

	elif "[Melee key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("kick"):
			if actionKey is InputEventKey:
				if not keys.empty():
					keys += " or "
				keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Melee key]", keys)
		return true

	elif "[Reload key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("reload"):
			if actionKey is InputEventKey:
				if not keys.empty():
					keys += " or "
				keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Reload key]", keys)
		return true

	elif "[Off-hand use key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("offhand_use"):
			if actionKey is InputEventKey:
				if not keys.empty():
					keys += " or "
				keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Off-hand use key]", keys)
		return true

	elif "[Off-hand switch key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("cycle_offhand_slot"):
			if actionKey is InputEventKey:
				if not keys.empty():
					keys += " or "
				keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Off-hand switch key]", keys)
		return true

	elif "[Off-hand throw key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("offhand_throw"):
			if actionKey is InputEventKey:
				if not keys.empty():
					keys += " or "
				keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Off-hand throw key]", keys)
		return true

	elif "[Main-hand throw key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("main_throw"):
			if actionKey is InputEventKey:
				if not keys.empty():
					keys += " or "
				keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Main-hand throw key]", keys)
		return true

	elif "[Main-hand use key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("main_use_primary"):
			if actionKey is InputEventKey:
				if not keys.empty():
					keys += " or "
				keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Main-hand use key]", keys)
		check_word()
		return

	elif "[Main-hand secondary key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("main_use_secondary"):
			if actionKey is InputEventKey:
				if not keys.empty():
					keys += " or "
				keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Main-hand secondary key]", keys)
		return true

	elif "[Map key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("map_menu"):
			if actionKey is InputEventKey:
				if not keys.empty():
					keys += " or "
				keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Map key]", keys)
		return true
	
	elif "[" in temp:
		printerr(temp) # this will catch wrong writing in list and mouse events (not implemented)
	
	return false


func load_files():
	var f = File.new()
	f.open(file1, File.READ)
	while not f.eof_reached(): # iterate through all lines until the end of file is reached
		temp = f.get_line()
		if not temp == "":
			while check_word():
				pass
			list1.append(temp)
			print(temp)
	f.close()
	
	f.open(file2, File.READ)
	while not f.eof_reached(): # iterate through all lines until the end of file is reached
		temp = f.get_line()
		if not temp == "":
			list2.append(temp)
	f.close()
	return
