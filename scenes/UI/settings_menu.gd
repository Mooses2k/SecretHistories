extends Control

signal settings_menu_exited()

func _gui_input(event):
	if event is InputEventMouseButton and event.is_pressed():
		self.hide()
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
