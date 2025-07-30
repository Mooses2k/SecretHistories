extends Control

const TabButtonScene = preload("../tab_button.tscn")
const GroupScene = preload("settings_group.tscn")
const GroupClass = preload("settings_group.gd")
const SettingEditor = preload("settings_editors/setting_editor.gd")
const SetDefaultKeyBtn = preload("set_default_keys.tscn")

const SettingsEditors = {
	SettingsClass.SettingType.BOOL : preload("settings_editors/bool_editor.tscn"),
	SettingsClass.SettingType.FLOAT : preload("settings_editors/float_editor.tscn"),
	SettingsClass.SettingType.ENUM : preload("settings_editors/enum_editor.tscn"),
	SettingsClass.SettingType.INT : preload("settings_editors/int_editor.tscn"),
	SettingsClass.SettingType.STRING : preload("settings_editors/string_editor.tscn")
}

@onready var tab_container = $MarginContainer/VBoxContainer/TabContainer
@onready var tab_buttons = $MarginContainer/VBoxContainer/TabButtons
@onready var content_area = $MarginContainer/VBoxContainer/ContentArea

var tab_data = {}
var current_tab = ""
var settings: SettingsClass

func attach_settings(s : SettingsClass, be_sorted : bool):
	clear_ui()
	settings = s

	# Check if we have the expected UI structure for tabbed settings
	if tab_buttons == null or content_area == null:
		print("WARNING: SettingsUI is using legacy scene structure, skipping tab generation")
		return

	generate_tabs()
	populate_settings()

func clear_ui():
	# Only proceed if we have the expected UI elements
	if tab_buttons == null or content_area == null:
		return

	for child in tab_buttons.get_children():
		child.queue_free()

	for child in content_area.get_children():
		child.queue_free()
	tab_data.clear()

func generate_tabs():
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

		# Create scroll container for tab content
		var scroll_container = ScrollContainer.new()
		scroll_container.name = "ScrollContainer_" + tab_name
		scroll_container.visible = first_tab

		# Configure scroll container to fill available space
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		# Configure scroll container properties
		scroll_container.set_horizontal_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
		scroll_container.set_vertical_scroll_mode(ScrollContainer.SCROLL_MODE_AUTO)
		scroll_container.set_follow_focus(true)

		# Create margin container to provide spacing from scroll bar
		# Adjust these margin values (in pixels) to customize the spacing:
		# - Left/Right margins provide horizontal spacing from scroll bar
		# - Top/Bottom margins provide vertical spacing from container edges
		var margin_container = MarginContainer.new()
		margin_container.name = "MarginContainer_" + tab_name
		margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		# Configure margin values - customize these as needed for visual spacing
		margin_container.add_theme_constant_override("margin_left", 12)    # Left spacing
		margin_container.add_theme_constant_override("margin_right", 12)   # Right spacing (from scroll bar)
		margin_container.add_theme_constant_override("margin_top", 8)      # Top spacing
		margin_container.add_theme_constant_override("margin_bottom", 8)   # Bottom spacing

		# Create tab content container
		var tab_content = VBoxContainer.new()
		tab_content.name = "TabContent_" + tab_name
		tab_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tab_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tab_content.add_theme_constant_override("separation", 8)

		# Add tab content to margin container, then margin container to scroll container
		margin_container.add_child(tab_content)
		scroll_container.add_child(margin_container)
		content_area.add_child(scroll_container)

		# Create groups for this tab
		for group_name in tab_structure[tab_name]:
			var group = GroupScene.instantiate()
			group.group_name = group_name
			tab_content.add_child(group)
			tab_data[tab_name] = tab_data.get(tab_name, {})
			tab_data[tab_name][group_name] = group

		if first_tab:
			current_tab = tab_name
			first_tab = false

func populate_settings():
	if not settings:
		return

	# Add default keys button for Input Key Settings
	var input_key_group = tab_data.get("Input", {}).get("Input Key Settings")
	if input_key_group:
		var default_keys_btn = SetDefaultKeyBtn.instantiate()
		input_key_group.add_editor(default_keys_btn)
		if input_key_group.get_node_or_null("ListOffset/SettingsList/Container/Button"):
			input_key_group.get_node("ListOffset/SettingsList/Container/Button").connect("pressed",
				Callable(get_parent().owner.get_node("ResetPanel"), "toggle_panel"))

	# Add all settings to appropriate groups
	for setting_name in settings.get_settings_list():
		var group_name = settings.get_setting_group(setting_name)
		if not group_name:
			continue

		# Find which tab this group belongs to
		for tab_name in tab_data.keys():
			if group_name in tab_data[tab_name]:
				var group = tab_data[tab_name][group_name]
				if group and setting_name != "Reset Keys":  # Skip the reset button
					add_setting_to_group(setting_name, group)
				break

func add_setting_to_group(setting_name: String, group: Node):
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
	var scroll_container = content_area.get_node("ScrollContainer_" + tab_name)
	if scroll_container:
		scroll_container.visible = true

	# Update button states
	for button in tab_buttons.get_children():
		button.button_pressed = (button.text == tab_name)

	current_tab = tab_name


func _on_ShowDebugOptions_pressed():
	get_parent().visible = !get_parent().visible
	if get_parent().visible:
		var parent_scroll : ScrollContainer = get_parent() as ScrollContainer
		parent_scroll.scroll_vertical = 0
		var h_scroll = parent_scroll.get_h_scroll_bar()
		parent_scroll.scroll_horizontal = max(h_scroll.max_value - h_scroll.page, 0)
