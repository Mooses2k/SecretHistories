extends VBoxContainer


export var default_group_name = "Settings"

const GroupScene = preload("SettingsGroup.tscn")
const GroupClass = preload("SettingsGroup.gd")
const SettingEditor = preload("SettingsEditors/SettingEditor.gd")

const SettingsEditors = {
	SettingsClass.SettingType.BOOL : preload("SettingsEditors/BoolEditor.tscn"),
	SettingsClass.SettingType.FLOAT : preload("SettingsEditors/FloatEditor.tscn"),
	SettingsClass.SettingType.ENUM : preload("SettingsEditors/EnumEditor.tscn"),
	SettingsClass.SettingType.INT : preload("SettingsEditors/IntEditor.tscn")
}

var group_nodes : Dictionary = Dictionary()
var settings : SettingsClass


func _ready():
	pass # Replace with function body.


func attach_settings(s : SettingsClass):
	clear_ui()
	settings = s
	generate_ui()


func clear_ui():
	for k in group_nodes.keys():
		group_nodes[k].queue_free()
	group_nodes.clear()
	pass


func generate_ui():
	for _s in settings.get_settings_list():
		var setting_name = _s as String
		add_setting(setting_name)
	pass


func add_setting(setting_name : String):
	var group_name = settings.get_setting_group(setting_name)
	group_name = group_name if group_name else default_group_name
	var settings_group : GroupClass = get_group_node(group_name)
	if settings_group == null:
		add_group(group_name)
		settings_group = get_group_node(group_name)
	var setting_editor = SettingsEditors[settings.get_setting_type(setting_name)].instance() as SettingEditor
	settings_group.add_editor(setting_editor)
	setting_editor.attach_setting(setting_name, settings)


func add_group(group_name : String) -> bool:
	if group_nodes.has(group_name):
		return false
	var new_group = GroupScene.instance()
	add_child(new_group)
	group_nodes[group_name] = new_group
	new_group.group_name = group_name
	return true


func has_group(group_name : String) -> bool:
	return group_nodes.has(group_name)
	pass


func get_group_node(group_name : String) -> GroupClass:
	return group_nodes.get(group_name)
	pass


func _on_ShowDebugOptions_pressed():
	$"..".visible = !$"..".visible
