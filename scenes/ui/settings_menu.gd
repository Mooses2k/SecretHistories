extends Control


signal settings_menu_exited()


func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if not $ChangeKeyPanel.visible:
			self.hide()
			if self.visible :
				emit_signal("settings_menu_exited")
		else:
			$ChangeKeyPanel.hide()


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
			"Input",
			"Input Key"
		]
		settings_ui.set_group_order(group_order)
	
	if settings_ui.has_method("set_tab_grouping_rules"):
		# Configure tab grouping for main settings
		settings_ui.set_tab_grouping_rules({
			"Video": ["Video Settings"],
			"Audio": ["Audio Settings"],
			"Game": ["Game Settings"],
			"Input": ["Input Settings", "Input Key Settings"]
		})
	
	if settings_ui.has_method("set_tab_order"):
		# Set preferred tab order
		var tab_order: Array[String] = [
			"Video",
			"Audio",
			"Game",
			"Input"
		]
		settings_ui.set_tab_order(tab_order)
	
	settings_ui.attach_settings(Settings, true)


func exit_state():
	self.visible = false


func enter_state():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	self.visible = true
