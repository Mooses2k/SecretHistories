extends VBoxContainer


#export var default_group_name = "Game Settings"

const SetDefaultKeyBtn = preload("set_default_keys.tscn")
const BlankRowScene = preload("blank_row.tscn")
const GroupScene = preload("settings_group.tscn")
const GroupClass = preload("settings_group.gd")
const SettingEditor = preload("settings_editors/setting_editor.gd")


const SettingsEditors = {
	SettingsClass.SettingType.BOOL : preload("settings_editors/bool_editor.tscn"),
	SettingsClass.SettingType.FLOAT : preload("settings_editors/float_editor.tscn"),
	SettingsClass.SettingType.ENUM : preload("settings_editors/enum_editor.tscn"),
	SettingsClass.SettingType.INT : preload("settings_editors/int_editor.tscn"),
	SettingsClass.SettingType.STRING : preload("settings_editors/string_editor.tscn")
}

var group_nodes : Dictionary = Dictionary()
var settings : SettingsClass
var is_first_settings : bool = true
var is_first_key_settings : bool = true

## Configuration for group ordering - can be set by caller
## Groups not in this list will be sorted alphabetically after these
var preferred_group_order : Array[String] = []

## Pattern to identify key-related groups for special handling
var key_group_pattern : String = "Key"


func attach_settings(s : SettingsClass, be_sorted : bool):
	print("NonTabbedSettingsUI: Attaching settings, be_sorted=", be_sorted)
	clear_ui()
	settings = s
	generate_ui()
	
	if be_sorted:
		sort_setting_groups()
	
	# Force update ScrollContainer content size after setup
	call_deferred("_update_scroll_content_size")


## Configure group ordering - should be called by the parent/caller
func set_group_order(group_order: Array[String]):
	preferred_group_order = group_order


func clear_ui():
	for k in group_nodes.keys():
		group_nodes[k].queue_free()
	group_nodes.clear()


func generate_ui():
	is_first_settings = true
	is_first_key_settings = true
	
	for _s in settings.get_settings_list():
		var setting_name = _s as String
		add_setting(setting_name)


func sort_setting_groups():
	## Collect all group nodes and their names
	var group_children : Array[Node] = []
	var blank_children : Array[Node] = []
	
	for child in get_children():
		if child.has_method("get_group_name"):
			group_children.append(child)
		else:
			# These are blank rows or other UI elements
			blank_children.append(child)
	
	## Sort groups based on preferred order, then alphabetically
	group_children.sort_custom(_compare_groups)
	
	## Remove all children temporarily
	for child in get_children():
		remove_child(child)
	
	## Re-add children in the correct order with blank rows between groups
	var is_first_group : bool = true
	for group_child in group_children:
		if not is_first_group:
			# Add a blank row between groups
			var blank_row = BlankRowScene.instantiate()
			add_child(blank_row)
		else:
			is_first_group = false
		
		add_child(group_child)
	
	## Add any remaining blank children at the end
	for blank_child in blank_children:
		add_child(blank_child)


## Custom comparison function for sorting groups
func _compare_groups(a : Node, b : Node) -> bool:
	var group_a : String = a.get_group_name().strip_edges()
	var group_b : String = b.get_group_name().strip_edges()
	
	var index_a : int = _get_group_priority(group_a)
	var index_b : int = _get_group_priority(group_b)
	
	# If both groups have defined priorities, sort by priority
	if index_a != -1 and index_b != -1:
		return index_a < index_b
	
	# If only one has a defined priority, it comes first
	if index_a != -1:
		return true
	if index_b != -1:
		return false
	
	# If neither has a defined priority, sort alphabetically
	return group_a < group_b


## Get the priority index of a group, or -1 if not in preferred order
func _get_group_priority(group_name : String) -> int:
	for i in range(preferred_group_order.size()):
		if group_name.contains(preferred_group_order[i]):
			return i
	return -1


func add_setting(setting_name : String):
	var group_name = settings.get_setting_group(setting_name)
#	group_name = group_name if group_name else default_group_name
	var settings_group : GroupClass = get_group_node(group_name)
	if settings_group == null:
		add_group(group_name)
		settings_group = get_group_node(group_name)
	
	# Check if this is a key-related group for special handling
	if _is_key_related_group(group_name) and is_first_key_settings:
		is_first_key_settings = false
		settings_group.add_editor(SetDefaultKeyBtn.instantiate())
		settings_group.get_node("ListOffset/SettingsList/Container/Button").connect("pressed", Callable(get_parent().owner.get_node("ResetPanel"), "toggle_panel"))
	
	var setting_editor = SettingsEditors[settings.get_setting_type(setting_name)].instantiate() as SettingEditor
	settings_group.add_editor(setting_editor)
	setting_editor.attach_setting(setting_name, settings)


func add_group(group_name : String) -> bool:
	if group_nodes.has(group_name):
		return false
	
	if is_first_settings:
		is_first_settings = false
	else:
		add_blank_row()
	
	var new_group = GroupScene.instantiate()
	add_child(new_group)
	group_nodes[group_name] = new_group
	new_group.group_name = str(group_name) + "\n"
	return true


func add_blank_row() -> void:
	var new_group = BlankRowScene.instantiate()
	add_child(new_group)


func has_group(group_name : String) -> bool:
	return group_nodes.has(group_name)


func get_group_node(group_name : String) -> GroupClass:
	return group_nodes.get(group_name)


## Check if a group name is related to key settings
func _is_key_related_group(group_name : String) -> bool:
	return group_name.to_lower().contains(key_group_pattern.to_lower())


func _on_ShowDebugOptions_pressed():
	get_parent().visible = !get_parent().visible
	if get_parent().visible:
		var parent_scroll : ScrollContainer = get_parent() as ScrollContainer
		parent_scroll.scroll_vertical = 0
		var h_scroll = parent_scroll.get_h_scroll_bar()
		parent_scroll.scroll_horizontal = max(h_scroll.max_value - h_scroll.page, 0)

## Force update ScrollContainer content size
func _update_scroll_content_size():
	print("NonTabbedSettingsUI: Updating scroll content size...")
	
	# Find the ScrollContainer in our hierarchy
	var scroll_container: ScrollContainer = get_parent()
	if not scroll_container is ScrollContainer:
		# Look up the hierarchy for a ScrollContainer
		var parent = get_parent()
		while parent:
			if parent is ScrollContainer:
				scroll_container = parent as ScrollContainer
				break
			parent = parent.get_parent()
	
	if scroll_container:
		print("NonTabbedSettingsUI: Found ScrollContainer, forcing content size update")
		# Force the ScrollContainer to recalculate its content size
		scroll_container.queue_sort()
		queue_sort()  # Also update our own layout
		print("NonTabbedSettingsUI: Content size updated")
	else:
		print("NonTabbedSettingsUI: Warning - No ScrollContainer found in hierarchy!")

## Debug function to print current hierarchy and sizes
func _debug_print_hierarchy():
	print("NonTabbedSettingsUI: === HIERARCHY DEBUG ===")
	print("Self size: ", size)
	print("Self size flags: H=", size_flags_horizontal, " V=", size_flags_vertical)
	print("Children count: ", get_child_count())
	
	for i in range(get_child_count()):
		var child = get_child(i)
		print("  Child ", i, " (", child.name, "): size=", child.size)
	
	# Check for ScrollContainer
	var scroll_container = get_parent()
	if scroll_container is ScrollContainer:
		print("ScrollContainer size: ", scroll_container.size)
		print("ScrollContainer content size: ", scroll_container.get_v_scroll_bar().max_value)
	
	print("NonTabbedSettingsUI: === END HIERARCHY DEBUG ===")
