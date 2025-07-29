extends Control

signal settings_menu_exited()

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if not $ChangeKeyPanel.visible:
			self.hide()
			if self.visible:
				emit_signal("settings_menu_exited")
		else:
			$ChangeKeyPanel.hide()

func _ready() -> void:
	self.hide()
	# Use the new tabbed interface - replace old SettingsUI with TabbedSettingsUI
	var settings_ui = $MaxAspectContainer/PanelContainer/MarginContainer/ScrollContainer/MarginContainer/SettingsUI
	if settings_ui:
		settings_ui.queue_free()
	
	# Load the tabbed settings UI
	var tabbed_settings_scene = preload("res://scenes/ui/tabbed_settings_ui.tscn")
	var tabbed_settings = tabbed_settings_scene.instantiate()
	tabbed_settings.name = "TabbedSettingsUI"
	$MaxAspectContainer/PanelContainer/MarginContainer/ScrollContainer/MarginContainer.add_child(tabbed_settings)
	tabbed_settings.attach_settings(Settings, true)
