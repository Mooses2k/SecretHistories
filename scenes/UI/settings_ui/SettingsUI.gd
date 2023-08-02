extends VBoxContainer


#export var default_group_name = "Game Settings"

const SetDefaultKeyBtn = preload("SetDefaultKeys.tscn")
const BlankRowScene = preload("BlankRow.tscn")
const GroupScene = preload("SettingsGroup.tscn")
const GroupClass = preload("SettingsGroup.gd")
const SettingEditor = preload("SettingsEditors/SettingEditor.gd")


const SettingsEditors = {
	SettingsClass.SettingType.BOOL : preload("SettingsEditors/BoolEditor.tscn"),
	SettingsClass.SettingType.FLOAT : preload("SettingsEditors/FloatEditor.tscn"),
	SettingsClass.SettingType.ENUM : preload("SettingsEditors/EnumEditor.tscn"),
	SettingsClass.SettingType.INT : preload("SettingsEditors/IntEditor.tscn"),
	SettingsClass.SettingType.STRING : preload("SettingsEditors/StringEditor.tscn")
}

var group_nodes : Dictionary = Dictionary()
var settings : SettingsClass
var is_first_settings : bool = true
var is_first_key_settings : bool = true
var is_done : bool = false
var index : int = 0
var counter : int = 0


func attach_settings(s : SettingsClass, be_sorted : bool):
	clear_ui()
	settings = s
	generate_ui()
	
	if be_sorted:
		sort_setting_groups()


func clear_ui():
	for k in group_nodes.keys():
		group_nodes[k].queue_free()
	group_nodes.clear()
	pass


func generate_ui():
	is_first_settings = true
	is_first_key_settings = true
	
	for _s in settings.get_settings_list():
		var setting_name = _s as String
		add_setting(setting_name)
	pass


func sort_setting_groups():
	while not is_done:
		index = -1
		counter = 0
		
		for child in get_children():
			index += 1
			
			if child.has_method("get_group_name"):
				if "Game" in str(child.group_name):
					if index != 0:
						swap_child(child, 0, index)
						break
					else:
						counter += 1
				elif "Video" in str(child.group_name):
					if index != 2:
						swap_child(child, 2, index)
						break
					else:
						counter += 1
				elif "Audio" in str(child.group_name):
					if index != 4:
						swap_child(child, 4, index)
						break
					else:
						counter += 1
				elif "Input" in str(child.group_name) and not "Key" in str(child.group_name):
					if index != 6:
						swap_child(child, 6, index)
						break
					else:
						counter += 1
				elif "Input Key" in str(child.group_name):
					if index != 8:
						swap_child(child, 8, index)
						break
					else:
						counter += 1
		
		if counter == 5:
			is_done = true


func swap_child(child : Node, target_index : int, current_index : int):
	move_child(child, get_child_count() - 1)
	move_child(get_child(target_index - 1), current_index) 
	move_child(child, target_index) 
	counter += 1


func add_setting(setting_name : String):
	var group_name = settings.get_setting_group(setting_name)
#	group_name = group_name if group_name else default_group_name
	var settings_group : GroupClass = get_group_node(group_name)
	if settings_group == null:
		add_group(group_name)
		settings_group = get_group_node(group_name)
	
	if group_name == "Input Key Settings" and is_first_key_settings:
		is_first_key_settings = false
		settings_group.add_editor(SetDefaultKeyBtn.instance())
		settings_group.get_node("ListOffset/SettingsList/Container/Button").connect("pressed", get_parent().owner.get_node("ResetPanel"), "toggle_panel")
	
	var setting_editor = SettingsEditors[settings.get_setting_type(setting_name)].instance() as SettingEditor
	settings_group.add_editor(setting_editor)
	setting_editor.attach_setting(setting_name, settings)


func add_group(group_name : String) -> bool:
	if group_nodes.has(group_name):
		return false
	
	if is_first_settings:
		is_first_settings = false
	else:
		add_blank_row()
	
	var new_group = GroupScene.instance()
	add_child(new_group)
	group_nodes[group_name] = new_group
	new_group.group_name = str(group_name) + "\n"
	return true


func add_blank_row() -> void:
	var new_group = BlankRowScene.instance()
	add_child(new_group)


func has_group(group_name : String) -> bool:
	return group_nodes.has(group_name)
	pass


func get_group_node(group_name : String) -> GroupClass:
	return group_nodes.get(group_name)
	pass


func _on_ShowDebugOptions_pressed():
	$"..".visible = !$"..".visible
