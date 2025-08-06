extends Control

signal tab_changed(tab_name: String)

@onready var tab_container = $MarginContainer/TabContainer

var settings: SettingsClass

func attach_settings(s: SettingsClass, be_sorted: bool = false):
	settings = s
	populate_settings()

func populate_settings():
	if not settings:
		return

	# Add all settings to appropriate groups by finding them in the scene
	for setting_name in settings.get_settings_list():
		var group_name = settings.get_setting_group(setting_name)
		if not group_name:
			continue

		# Find the group node in the scene structure
		var group_node = find_group_node(group_name)
		if group_node:
			add_setting_to_group(setting_name, group_node)
		else:
			print("Warning: Could not find group node for: ", group_name)

func find_group_node(group_name: String) -> Node:
	# Search through all tabs to find the group with matching name
	for tab in tab_container.get_children():
		if tab is ScrollContainer:
			var margin_container = tab.get_child(0) if tab.get_child_count() > 0 else null
			if margin_container is MarginContainer:
				var vbox = margin_container.get_child(0) if margin_container.get_child_count() > 0 else null
				if vbox is VBoxContainer:
					for group in vbox.get_children():
						if group.has_method("get_group_name"):
							var current_group_name = group.get_group_name()
							if current_group_name == group_name:
								return group
	return null

func add_setting_to_group(setting_name: String, group: Node):
	var SettingsEditors = {
		SettingsClass.SettingType.BOOL: preload("settings_ui/settings_editors/bool_editor.tscn"),
		SettingsClass.SettingType.FLOAT: preload("settings_ui/settings_editors/float_editor.tscn"),
		SettingsClass.SettingType.ENUM: preload("settings_ui/settings_editors/enum_editor.tscn"),
		SettingsClass.SettingType.INT: preload("settings_ui/settings_editors/int_editor.tscn"),
		SettingsClass.SettingType.STRING: preload("settings_ui/settings_editors/string_editor.tscn")
	}

	var setting_editor = SettingsEditors[settings.get_setting_type(setting_name)].instantiate()
	group.add_editor(setting_editor)
	setting_editor.attach_setting(setting_name, settings)

func _on_tab_changed(tab_index: int):
	if tab_index >= 0 and tab_index < tab_container.get_tab_count():
		var tab_name = tab_container.get_tab_title(tab_index)
		emit_signal("tab_changed", tab_name)

func get_current_tab_name() -> String:
	if tab_container.current_tab >= 0:
		return tab_container.get_tab_title(tab_container.current_tab)
	return ""
