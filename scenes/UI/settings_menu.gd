extends Control


signal settings_menu_exited()


func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		self.hide()
		if self.visible :
			emit_signal("settings_menu_exited")


func _ready() -> void:
	self.hide()
	$"%SettingsUI".attach_settings(Settings, true)


func exit_state():
	self.visible = false
	pass


func enter_state():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	self.visible = true
	pass
