extends Control


signal settings_menu_exited()


func _gui_input(event):
	if event is InputEventMouseButton and event.is_pressed() and event.is_action_pressed("Left_Mouse_Button"):
		self.hide()
		emit_signal("settings_menu_exited")


func _unhandled_input(event):
	if event is InputEventKey and event.is_action_pressed("ui_cancel"):
		self.hide()
		if self.visible :
			emit_signal("settings_menu_exited")


func _ready() -> void:
	self.hide()
	$"%SettingsUI".attach_settings(Settings)


func exit_state():
	self.visible = false
	pass


func enter_state():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	self.visible = true
	pass
