extends Control

## Adaptive Settings UI Controller
## Automatically chooses between tabbed and non-tabbed settings interfaces
## based on the number of setting groups in the provided SettingsClass.

const TabbedSettingsUI = preload("tabbed_settings_ui.gd")
const NonTabbedSettingsUI = preload("settings_ui/settings_ui.gd")
const TabbedSettingsScene = preload("tabbed_settings_ui.tscn")
const NonTabbedSettingsScene = preload("settings_ui/settings_ui.tscn")

const TABBED_THRESHOLD: int = 2

var current_ui: Control
var settings: SettingsClass
var is_tabbed_mode: bool = false

## Configuration methods that forward to the current UI
## These store the configuration and apply it when the UI is created
var stored_group_order: Array[String] = []
var stored_tab_grouping_rules: Dictionary = {}
var stored_tab_order: Array[String] = []


## Forward signals from the current UI
func _ready():
	# Connect to child UI signals when they become available
	if current_ui:
		_connect_ui_signals()


## Main interface method - maintains backward compatibility
func attach_settings(settings_instance: SettingsClass, be_sorted: bool = true):
	settings = settings_instance
	_determine_ui_type()
	_create_appropriate_ui()
	_attach_settings_to_ui(be_sorted)


## Analyzes the SettingsClass to count unique groups
func _determine_ui_type():
	if not settings:
		is_tabbed_mode = false
		print("AdaptiveSettingsUI: No settings provided, using non-tabbed interface")
		return
	
	var unique_groups: Dictionary = {}
	var settings_list: Array = settings.get_settings_list()
	
	print("AdaptiveSettingsUI: Analyzing ", settings_list.size(), " settings...")
	
	# Count unique groups
	for setting_name in settings_list:
		var group_name: String = settings.get_setting_group(setting_name)
		print("AdaptiveSettingsUI: Setting '", setting_name, "' -> Group '", group_name, "'")
		if group_name and not group_name.is_empty():
			unique_groups[group_name] = true
	
	var group_count: int = unique_groups.size()
	is_tabbed_mode = group_count >= TABBED_THRESHOLD
	
	print("AdaptiveSettingsUI: Found ", group_count, " unique groups: ", unique_groups.keys())
	print("AdaptiveSettingsUI: Threshold is ", TABBED_THRESHOLD, ", using ",
		  "tabbed" if is_tabbed_mode else "non-tabbed", " interface")


## Creates and configures the appropriate UI
func _create_appropriate_ui():
	# Clear any existing UI
	_clear_current_ui()
	
	# Attempt to create the appropriate UI with graceful fallback
	var ui_created_successfully: bool = false
	
	if is_tabbed_mode:
		ui_created_successfully = _create_tabbed_ui()
	else:
		ui_created_successfully = _create_non_tabbed_ui()
	
	# Graceful fallback to non-tabbed UI if anything goes wrong
	if not ui_created_successfully and is_tabbed_mode:
		print("AdaptiveSettingsUI: Error creating tabbed UI, falling back to non-tabbed interface")
		is_tabbed_mode = false
		_clear_current_ui()
		_create_non_tabbed_ui()


## Creates the tabbed settings UI
func _create_tabbed_ui() -> bool:
	if TabbedSettingsScene:
		current_ui = TabbedSettingsScene.instantiate()
	else:
		# Fallback: create tabbed UI programmatically
		current_ui = Control.new()
		current_ui.set_script(TabbedSettingsUI)
	
	if current_ui:
		_add_ui_to_scene()
		return true
	return false

## Creates the non-tabbed settings UI
func _create_non_tabbed_ui() -> bool:
	if NonTabbedSettingsScene:
		current_ui = NonTabbedSettingsScene.instantiate()
	else:
		# Fallback: create non-tabbed UI programmatically
		current_ui = VBoxContainer.new()
		current_ui.set_script(NonTabbedSettingsUI)
	
	if current_ui:
		_add_ui_to_scene()
		return true
	return false

## Adds the UI to the scene and configures it
func _add_ui_to_scene():
	if not current_ui:
		return
	
	# Configure the UI to fill the available space
	current_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	add_child(current_ui)
	
	# Force immediate layout update
	call_deferred("_force_layout_update")


## Attaches settings to the current UI
func _attach_settings_to_ui(be_sorted: bool):
	if not current_ui or not settings:
		return
	
	# Apply stored configuration before attaching settings
	_apply_stored_configuration()
	
	# Both UI types should have the attach_settings method
	if current_ui.has_method("attach_settings"):
		if is_tabbed_mode:
			# Tabbed UI doesn't use the be_sorted parameter
			current_ui.attach_settings(settings)
		else:
			# Non-tabbed UI uses the be_sorted parameter
			current_ui.attach_settings(settings, be_sorted)
	else:
		print("AdaptiveSettingsUI: Warning - UI doesn't have attach_settings method")


## Configure group ordering for non-tabbed UI
func set_group_order(group_order: Array[String]):
	stored_group_order = group_order
	if current_ui and current_ui.has_method("set_group_order"):
		current_ui.set_group_order(group_order)


## Configure tab grouping rules for tabbed UI
func set_tab_grouping_rules(grouping_rules: Dictionary):
	stored_tab_grouping_rules = grouping_rules
	if current_ui and current_ui.has_method("set_tab_grouping_rules"):
		current_ui.set_tab_grouping_rules(grouping_rules)


## Configure tab order for tabbed UI
func set_tab_order(tab_order: Array[String]):
	stored_tab_order = tab_order
	if current_ui and current_ui.has_method("set_tab_order"):
		current_ui.set_tab_order(tab_order)


## Apply stored configuration to the current UI
func _apply_stored_configuration():
	if not current_ui:
		return
	
	# Apply group order for non-tabbed UI
	if not stored_group_order.is_empty() and current_ui.has_method("set_group_order"):
		current_ui.set_group_order(stored_group_order)
	
	# Apply tab configuration for tabbed UI
	if not stored_tab_grouping_rules.is_empty() and current_ui.has_method("set_tab_grouping_rules"):
		current_ui.set_tab_grouping_rules(stored_tab_grouping_rules)
	
	if not stored_tab_order.is_empty() and current_ui.has_method("set_tab_order"):
		current_ui.set_tab_order(stored_tab_order)

## Clears the current UI
func _clear_current_ui():
	if current_ui:
		current_ui.queue_free()
		current_ui = null

## Forward common methods to the current UI for compatibility

## Gets the current UI instance (for advanced usage)
func get_current_ui() -> Control:
	return current_ui

## Checks if currently using tabbed mode
func is_using_tabbed_mode() -> bool:
	return is_tabbed_mode

## Gets the number of unique groups in the current settings
func get_group_count() -> int:
	if not settings:
		return 0
	
	var unique_groups: Dictionary = {}
	var settings_list: Array = settings.get_settings_list()
	
	for setting_name in settings_list:
		var group_name: String = settings.get_setting_group(setting_name)
		if group_name and not group_name.is_empty():
			unique_groups[group_name] = true
	
	return unique_groups.size()


func _connect_ui_signals():
	# Connect tabbed UI specific signals
	if is_tabbed_mode and current_ui.has_signal("tab_changed"):
		if not current_ui.is_connected("tab_changed", _on_tab_changed):
			current_ui.connect("tab_changed", _on_tab_changed)


func _on_tab_changed(tab_name: String):
	# Forward the signal or handle tab changes if needed
	pass


## Force layout update for proper sizing
func _force_layout_update():
	if current_ui:
		# Force the current UI to recalculate its size
		current_ui.notification(NOTIFICATION_RESIZED)
		# Also ensure we have proper size flags
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL


## Cleanup
func _exit_tree():
	_clear_current_ui()
