extends Control

signal tab_changed(tab_name: String)

const TabButtonScene = preload("tab_button.tscn")
const SettingsGroupScene = preload("settings_ui/settings_group.tscn")
const GroupClass = preload("settings_ui/settings_group.gd")

@onready var tab_container = $TabContainer
@onready var tab_buttons = $TabButtons
@onready var content_area = $ContentArea

var tab_data = {}
var current_tab = ""
var settings: SettingsClass

func attach_settings(s: SettingsClass):
	settings = s
	generate_tabs()

func generate_tabs():
	# Ensure required nodes exist
	ensure_nodes_exist()

	# Clear existing tabs
	if tab_buttons:
		for child in tab_buttons.get_children():
			child.queue_free()
	if content_area:
		for child in content_area.get_children():
			child.queue_free()

	tab_data.clear()

	# Define our tab structure
	var tab_structure = {
		"Video": ["Video Settings"],
		"Audio": ["Audio Settings"],
		"Game": ["Game Settings"],
		"Input": ["Input Settings", "Input Key Settings"]
	}

	# Create tabs
	var first_tab = true
	for tab_name in tab_structure.keys():
		# Create tab button
		var tab_button = TabButtonScene.instantiate()
		tab_button.text = tab_name
		tab_button.pressed.connect(_on_tab_button_pressed.bind(tab_name))
		tab_buttons.add_child(tab_button)

		# Create tab content
		var tab_content = VBoxContainer.new()
		tab_content.name = "TabContent_" + tab_name
		tab_content.visible = first_tab
		tab_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_area.add_child(tab_content)

		# Create groups for this tab
		for group_name in tab_structure[tab_name]:
			var group = SettingsGroupScene.instantiate()
			group.group_name = group_name
			tab_content.add_child(group)
			tab_data[tab_name] = tab_data.get(tab_name, {})
			tab_data[tab_name][group_name] = group

		if first_tab:
			current_tab = tab_name
			first_tab = false

	# Populate settings
	populate_settings()

func ensure_nodes_exist():
	# Create missing nodes if they don't exist
	if not tab_buttons:
		tab_buttons = HBoxContainer.new()
		tab_buttons.name = "TabButtons"
		add_child(tab_buttons)

	if not content_area:
		content_area = Control.new()
		content_area.name = "ContentArea"
		content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(content_area)

func populate_settings():
	if not settings:
		return

	for setting_name in settings.get_settings_list():
		var group_name = settings.get_setting_group(setting_name)
		if not group_name:
			continue

		# Find which tab this group belongs to
		for tab_name in tab_data.keys():
			if group_name in tab_data[tab_name]:
				var group = tab_data[tab_name][group_name]
				if group:
					add_setting_to_group(setting_name, group)
				break

func add_setting_to_group(setting_name: String, group: Node):
	const SettingEditor = preload("settings_ui/settings_editors/setting_editor.gd")
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

func _on_tab_button_pressed(tab_name: String):
	if tab_name == current_tab:
		return

	# Hide all tab contents
	for child in content_area.get_children():
		child.visible = false

	# Show selected tab content
	var tab_content = content_area.get_node("TabContent_" + tab_name)
	if tab_content:
		tab_content.visible = true

	# Update button states
	for button in tab_buttons.get_children():
		button.button_pressed = (button.text == tab_name)

	current_tab = tab_name
	emit_signal("tab_changed", tab_name)
