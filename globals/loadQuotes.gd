extends Node

onready var file1 = 'res://resources/list1.txt' #text files on 'resources' folder
onready var file2 = 'res://resources/list2.txt'


var list1 : PoolStringArray
var list2 : PoolStringArray
var temp
var keys = ""


func check_word():
	if "[Interact key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("interact"):
			if not keys.empty():
				keys += " or "
			keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Interact key]", keys)
		check_word()
		return

	elif "[Move_right key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("move_right"):
			if not keys.empty():
				keys += " or "
			keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Move_right key]", keys)
		check_word()
		return

	elif "[Move_left key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("move_left"):
			if not keys.empty():
				keys += " or "
			keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Move_left key]", keys)
		check_word()
		return

	elif "[Move_up key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("move_up"):
			if not keys.empty():
				keys += " or "
			keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Move_up key]", keys)
		check_word()
		return

	elif "[Move_down key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("move_down"):
			if not keys.empty():
				keys += " or "
			keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Move_down key]", keys)
		check_word()
		return

	elif "[Sprint key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("sprint"):
			if not keys.empty():
				keys += " or "
			keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Sprint key]", keys)
		check_word()
		return

	elif "[Kick key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("kick"):
			if not keys.empty():
				keys += " or "
			keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Kick key]", keys)
		check_word()
		return

	elif "[Reload key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("reload"):
			if not keys.empty():
				keys += " or "
			keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Reload key]", keys)
		check_word()
		return

	elif "[Offhand use key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("offhand_use"):
			if not keys.empty():
				keys += " or "
			keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Offhand use key]", keys)
		check_word()
		return

	elif "[Offhand throw key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("offhand_throw"):
			if not keys.empty():
				keys += " or "
			keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Offhand throw key]", keys)
		check_word()
		return

	elif "[Inventory key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("inventory_menu"):
			if not keys.empty():
				keys += " or "
			keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Inventory key]", keys)
		check_word()
		return

	elif "[Map key]" in temp:
		keys = ""
		for actionKey in InputMap.get_action_list("map_menu"):
			if not keys.empty():
				keys += " or "
			keys += OS.get_scancode_string(actionKey.scancode)
		temp = temp.replace("[Map key]", keys)
		check_word()
		return


func load_files():
	var f = File.new()
	f.open(file1, File.READ)
	while not f.eof_reached(): # iterate through all lines until the end of file is reached
		temp = f.get_line()
		if not temp == "":
			check_word()
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
