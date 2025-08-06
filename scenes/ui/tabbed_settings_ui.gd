extends Control

signal tab_changed(tab_name: String)

const TabButtonScene = preload("tab_button.tscn")
const SettingsGroupScene = preload("settings_ui/settings_group.tscn")
const GroupClass = preload("settings_ui/settings_group.gd")
const SetDefaultKeyBtn = preload("settings_ui/set_default_keys.tscn")

var tab_container: VBoxContainer
var tab_buttons: HBoxContainer
var content_area: VBoxContainer

var tab_data = {}
var current_tab = ""
var settings: SettingsClass

## Configuration for intelligent tab grouping - can be set by caller
## Empty rules mean each group gets its own tab
var tab_grouping_rules: Dictionary = {}

## Preferred tab order - can be set by caller
var preferred_tab_order: Array[String] = []

## Pattern to identify key-related groups for special handling
var key_group_pattern: String = "Key"
var is_first_key_settings: bool = true

func attach_settings(s: SettingsClass):
	settings = s
	generate_tabs()


## Configure tab grouping rules - should be called by the parent/caller
func set_tab_grouping_rules(grouping_rules: Dictionary):
	tab_grouping_rules = grouping_rules


## Configure tab order - should be called by the parent/caller
func set_tab_order(tab_order: Array[String]):
	preferred_tab_order = tab_order

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
	is_first_key_settings = true

	# Dynamically detect all groups from settings
	var detected_groups = _detect_settings_groups()

	# Create intelligent tab structure based on detected groups
	var tab_structure = _create_tab_structure(detected_groups)

	# Create tabs in preferred order
	var ordered_tabs = _get_ordered_tabs(tab_structure.keys())
	var first_tab = true

	for tab_name in ordered_tabs:
		var groups_for_tab = tab_structure[tab_name]

		# Create tab button
		var tab_button = TabButtonScene.instantiate()
		tab_button.text = tab_name
		tab_button.pressed.connect(_on_tab_button_pressed.bind(tab_name))
		tab_buttons.add_child(tab_button)

		# Create tab content with proper spacing
		var tab_content = VBoxContainer.new()
		tab_content.name = "TabContent_" + tab_name
		tab_content.visible = first_tab
		tab_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Add spacing between groups
		tab_content.add_theme_constant_override("separation", 20)
		content_area.add_child(tab_content)

		# Create groups for this tab with spacing
		for i in range(groups_for_tab.size()):
			var group_name = groups_for_tab[i]
			var group = SettingsGroupScene.instantiate()
			group.group_name = group_name
			tab_content.add_child(group)
			tab_data[tab_name] = tab_data.get(tab_name, {})
			tab_data[tab_name][group_name] = group

			# Add spacing after each group except the last one
			if i < groups_for_tab.size() - 1:
				var group_spacer = Control.new()
				group_spacer.custom_minimum_size = Vector2(0, 12)
				tab_content.add_child(group_spacer)

		if first_tab:
			current_tab = tab_name
			first_tab = false

	# Populate settings
	populate_settings()

## Detect all unique groups from the settings
func _detect_settings_groups() -> Array[String]:
	var groups: Array[String] = []

	if not settings:
		return groups

	for setting_name in settings.get_settings_list():
		var group_name = settings.get_setting_group(setting_name)
		if group_name and not groups.has(group_name):
			groups.append(group_name)

	return groups

## Create intelligent tab structure based on detected groups
func _create_tab_structure(detected_groups: Array[String]) -> Dictionary:
	var tab_structure: Dictionary = {}
	var unassigned_groups: Array[String] = detected_groups.duplicate()

	# Apply grouping rules if any are configured
	if not tab_grouping_rules.is_empty():
		for tab_name in tab_grouping_rules.keys():
			var rule_groups = tab_grouping_rules[tab_name]
			var matched_groups: Array[String] = []

			# Find groups that match this rule
			for rule_group in rule_groups:
				for detected_group in detected_groups:
					if detected_group == rule_group:
						matched_groups.append(detected_group)
						unassigned_groups.erase(detected_group)

			# Only create tab if we found matching groups
			if matched_groups.size() > 0:
				tab_structure[tab_name] = matched_groups

	# Handle unassigned groups - create individual tabs with clean names
	for group_name in unassigned_groups:
		var clean_tab_name = _get_clean_tab_name(group_name)
		tab_structure[clean_tab_name] = [group_name]

	return tab_structure

## Get clean tab name by removing "Settings" suffix and other cleanup
func _get_clean_tab_name(group_name: String) -> String:
	var clean_name = group_name

	# Remove "Settings" suffix
	if clean_name.ends_with(" Settings"):
		clean_name = clean_name.substr(0, clean_name.length() - 9)
	elif clean_name.ends_with("Settings"):
		clean_name = clean_name.substr(0, clean_name.length() - 8)

	# Handle special cases
	if clean_name.is_empty():
		clean_name = group_name  # Fallback to original name

	return clean_name

## Get tabs in preferred order, with unrecognized tabs at the end
func _get_ordered_tabs(tab_names: Array) -> Array[String]:
	var ordered: Array[String] = []
	var remaining: Array[String] = []

	# Add tabs in preferred order if configured
	if not preferred_tab_order.is_empty():
		for preferred_tab in preferred_tab_order:
			if tab_names.has(preferred_tab):
				ordered.append(preferred_tab)

	# Add remaining tabs alphabetically
	for tab_name in tab_names:
		if not ordered.has(tab_name):
			remaining.append(tab_name)

	remaining.sort()
	ordered.append_array(remaining)

	return ordered

func ensure_nodes_exist():
	print("TabbedSettingsUI: Ensuring nodes exist...")

	# Try to get existing nodes first (for scene-based instantiation)
	if not tab_buttons:
		tab_buttons = get_node_or_null("MarginContainer/VBoxContainer/TabButtons")
		if not tab_buttons:
			tab_buttons = get_node_or_null("VBoxContainer/TabButtons")
	if not content_area:
		content_area = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/ScrollMarginContainer/ContentArea")
		if not content_area:
			content_area = get_node_or_null("VBoxContainer/ContentArea")
	# Note: tab_container is no longer needed since ContentArea is now a VBoxContainer

	print("TabbedSettingsUI: Found existing nodes - tab_buttons: ", tab_buttons != null, ", content_area: ", content_area != null)

	# Create missing nodes if they don't exist (for programmatic instantiation)
	if not tab_buttons:
		print("TabbedSettingsUI: Creating programmatic UI structure")

		# Check if we're already inside a ScrollContainer
		var is_inside_scroll_container = false
		var parent = get_parent()
		while parent:
			if parent is ScrollContainer:
				is_inside_scroll_container = true
				print("TabbedSettingsUI: Detected we're inside an existing ScrollContainer")
				break
			parent = parent.get_parent()

		# Create the structure - simpler if we're inside a ScrollContainer
		var main_container: Control
		if is_inside_scroll_container:
			# Don't add margins if we're inside a ScrollContainer - let the parent handle it
			main_container = VBoxContainer.new()
			main_container.name = "VBoxContainer"
			main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			add_child(main_container)
		else:
			# Create full structure with margins and internal ScrollContainer
			var margin_container = MarginContainer.new()
			margin_container.name = "MarginContainer"
			margin_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			margin_container.add_theme_constant_override("margin_left", 16)
			margin_container.add_theme_constant_override("margin_top", 16)
			margin_container.add_theme_constant_override("margin_right", 16)
			margin_container.add_theme_constant_override("margin_bottom", 16)
			add_child(margin_container)

			main_container = VBoxContainer.new()
			main_container.name = "VBoxContainer"
			main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			margin_container.add_child(main_container)

		# Tab buttons with spacing below
		tab_buttons = HBoxContainer.new()
		tab_buttons.name = "TabButtons"
		tab_buttons.add_theme_constant_override("separation", 8)
		main_container.add_child(tab_buttons)

		# Add spacer between tabs and content
		var tab_spacer = Control.new()
		tab_spacer.custom_minimum_size = Vector2(0, 16)
		main_container.add_child(tab_spacer)

		# Content area - create ScrollContainer only if we're not inside one
		if is_inside_scroll_container:
			# Direct content area without ScrollContainer
			content_area = VBoxContainer.new()
			content_area.name = "ContentArea"
			content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
			main_container.add_child(content_area)
		else:
			# Create internal ScrollContainer
			var scroll_container = ScrollContainer.new()
			scroll_container.name = "ScrollContainer"
			scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			main_container.add_child(scroll_container)

			# Create margin container inside scroll container for proper spacing
			var scroll_margin = MarginContainer.new()
			scroll_margin.name = "ScrollMarginContainer"
			scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll_margin.add_theme_constant_override("margin_left", 16)
			scroll_margin.add_theme_constant_override("margin_right", 24)
			scroll_container.add_child(scroll_margin)

			content_area = VBoxContainer.new()
			content_area.name = "ContentArea"
			content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll_margin.add_child(content_area)

	# Ensure content_area is properly configured for expansion
	if content_area:
		content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		print("TabbedSettingsUI: ContentArea configured with size flags: ", content_area.size_flags_horizontal, ", ", content_area.size_flags_vertical)

		# Add debug call to print hierarchy after setup
		call_deferred("_debug_print_hierarchy")

func populate_settings():
	if not settings:
		return

	print("TabbedSettingsUI: Starting to populate settings")

	for setting_name in settings.get_settings_list():
		var group_name = settings.get_setting_group(setting_name)
		if not group_name:
			continue

		# Find which tab this group belongs to
		for tab_name in tab_data.keys():
			if group_name in tab_data[tab_name]:
				var group = tab_data[tab_name][group_name]
				if group:
					add_setting_to_group(setting_name, group, group_name)
				break

	# Force update ScrollContainer content size after populating
	call_deferred("_update_scroll_content_size")

func add_setting_to_group(setting_name: String, group: Node, group_name: String):
	const SettingEditor = preload("settings_ui/settings_editors/setting_editor.gd")
	var SettingsEditors = {
		SettingsClass.SettingType.BOOL: preload("settings_ui/settings_editors/bool_editor.tscn"),
		SettingsClass.SettingType.FLOAT: preload("settings_ui/settings_editors/float_editor.tscn"),
		SettingsClass.SettingType.ENUM: preload("settings_ui/settings_editors/enum_editor.tscn"),
		SettingsClass.SettingType.INT: preload("settings_ui/settings_editors/int_editor.tscn"),
		SettingsClass.SettingType.STRING: preload("settings_ui/settings_editors/string_editor.tscn")
	}

	# Check if this is a key-related group for special handling
	if _is_key_related_group(group_name) and is_first_key_settings:
		is_first_key_settings = false
		var reset_btn = SetDefaultKeyBtn.instantiate()
		group.add_editor(reset_btn)
		# Connect to reset panel if it exists (maintaining compatibility with existing UI structure)
		var reset_panel_path = "ResetPanel"
		var owner_node = get_parent()
		if owner_node and owner_node.owner:
			var reset_panel = owner_node.owner.get_node_or_null(reset_panel_path)
			if reset_panel and reset_panel.has_method("toggle_panel"):
				var button_node = reset_btn.get_node_or_null("ListOffset/SettingsList/Container/Button")
				if button_node:
					button_node.connect("pressed", Callable(reset_panel, "toggle_panel"))

	var setting_editor = SettingsEditors[settings.get_setting_type(setting_name)].instantiate()
	group.add_editor(setting_editor)
	setting_editor.attach_setting(setting_name, settings)

## Check if a group name is related to key settings
func _is_key_related_group(group_name: String) -> bool:
	return group_name.to_lower().contains(key_group_pattern.to_lower())

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

## Force update ScrollContainer content size
func _update_scroll_content_size():
	print("TabbedSettingsUI: Updating scroll content size...")

	# Find the ScrollContainer in our hierarchy
	var scroll_container: ScrollContainer = null

	# First check if we're using the scene-based structure
	scroll_container = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer")

	# If not found, check if we're inside an external ScrollContainer
	if not scroll_container:
		var parent = get_parent()
		while parent:
			if parent is ScrollContainer:
				scroll_container = parent as ScrollContainer
				break
			parent = parent.get_parent()

	if scroll_container:
		print("TabbedSettingsUI: Found ScrollContainer, forcing content size update")
		# Force the ScrollContainer to recalculate its content size
		scroll_container.queue_sort()

		# Also ensure all tab content containers are properly sized
		if content_area:
			for child in content_area.get_children():
				if child is VBoxContainer:
					child.queue_sort()
					print("TabbedSettingsUI: Updated VBoxContainer size for tab content")
	else:
		print("TabbedSettingsUI: Warning - No ScrollContainer found in hierarchy!")

## Debug function to print current hierarchy and sizes
func _debug_print_hierarchy():
	print("TabbedSettingsUI: === HIERARCHY DEBUG ===")
	print("Self size: ", size)
	print("Self size flags: H=", size_flags_horizontal, " V=", size_flags_vertical)

	if content_area:
		print("ContentArea size: ", content_area.size)
		print("ContentArea size flags: H=", content_area.size_flags_horizontal, " V=", content_area.size_flags_vertical)
		print("ContentArea children count: ", content_area.get_child_count())

		for i in range(content_area.get_child_count()):
			var child = content_area.get_child(i)
			print("  Child ", i, " (", child.name, "): size=", child.size, " visible=", child.visible)

	# Check for ScrollContainer
	var scroll_container = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer")
	if not scroll_container:
		var parent = get_parent()
		while parent:
			if parent is ScrollContainer:
				scroll_container = parent as ScrollContainer
				break
			parent = parent.get_parent()

	if scroll_container:
		print("ScrollContainer size: ", scroll_container.size)
		print("ScrollContainer content size: ", scroll_container.get_v_scroll_bar().max_value)

	print("TabbedSettingsUI: === END HIERARCHY DEBUG ===")
