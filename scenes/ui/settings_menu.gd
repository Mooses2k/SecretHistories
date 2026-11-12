extends Control


signal settings_menu_exited()


## Escape (keyboard only) leaves the settings menu; mouse buttons never do.
## ui_cancel carries RMB project-wide, and RMB must stay free for rebinding
## inside the input menu, so back navigation here reads the raw event and
## ignores everything that is not a keyboard press. During capture the
## string editor consumes Escape first, so capture-cancel never exits.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.is_pressed():
		return
	if not key_event.is_action_pressed("ui_cancel"):
		return
	if $ChangeKeyPanel.visible:
		return
	emit_signal("settings_menu_exited")
	self.hide()
	get_viewport().set_input_as_handled()


func _ready() -> void:
	self.hide()
	
	# Configure the settings UI with proper ordering
	var settings_ui = %SettingsUI
	if settings_ui.has_method("set_group_order"):
		# Set the preferred order for main settings
		var group_order: Array[String] = [
			"Video",
			"Audio",
			"Game",
			"Gunplay",
			"Input",
			"Input Key"
		]
		settings_ui.set_group_order(group_order)

	if settings_ui.has_method("set_tab_grouping_rules"):
		# Configure tab grouping for main settings. Gunplay is sectioned
		# inside the Game tab (owner ruling, 2026-11-09), not its own tab.
		settings_ui.set_tab_grouping_rules({
			"Video": ["Video Settings"],
			"Audio": ["Audio Settings"],
			"Game": ["Game Settings", "Gunplay"],
			"Input": ["Input Settings", "Input Key Settings"],
			"Gamepad": ["Gamepad Key Settings"]
		})

	if settings_ui.has_method("set_tab_order"):
		# Set preferred tab order
		var tab_order: Array[String] = [
			"Video",
			"Audio",
			"Game",
			"Input",
			"Gamepad"
		]
		settings_ui.set_tab_order(tab_order)
	
	settings_ui.attach_settings(Settings, true)


func exit_state():
	self.visible = false


func enter_state():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	self.visible = true
