extends Control


signal button_pressed(button)

enum EscMenuButtons {
	RESUME,
	SAVE,
	SETTINGS,
	HELP,
	QUIT
}


func exit_state():
	self.visible = false


func enter_state():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	self.visible = true


func _on_ResumeButton_pressed() -> void:
	emit_signal("button_pressed", EscMenuButtons.RESUME)


func _on_SaveButton_pressed() -> void:
	emit_signal("button_pressed", EscMenuButtons.SAVE)


func _on_SettingsButton_pressed():
	emit_signal("button_pressed", EscMenuButtons.SETTINGS)


func _on_HelpButton_pressed():
	emit_signal("button_pressed", EscMenuButtons.HELP)


func _on_QuitButton_pressed() -> void:
	emit_signal("button_pressed", EscMenuButtons.QUIT)


func _input(event):
	if event.is_action_pressed("misc|fullscreen"):
		VideoSettings.set_fullscreen_enabled(!VideoSettings.fullscreen_enabled)

