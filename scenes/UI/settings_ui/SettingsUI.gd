extends VBoxContainer


export var default_group_name = "Game Settings"

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


func attach_settings(s : SettingsClass):
	clear_ui()
	settings = s
	generate_ui()
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
	for child in get_children():
		print("groups " + str(child))
#		match child.group_name:
#			"Game Settings":
#				pass
#			"Video Settings":
#				pass
#			"Audio Settings":
#				pass
#			"Input Settings":
#				pass
#			"Input Key Settings":
#				pass
#			_:
#				pass
	pass


func add_setting(setting_name : String):
	var group_name = settings.get_setting_group(setting_name)
	group_name = group_name if group_name else default_group_name
	var settings_group : GroupClass = get_group_node(group_name)
	if settings_group == null:
		add_group(group_name)
		settings_group = get_group_node(group_name)
	
	if group_name == "Input Key Settings" and is_first_key_settings:
		is_first_key_settings = false
		settings_group.add_editor(SetDefaultKeyBtn.instance())
	
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
