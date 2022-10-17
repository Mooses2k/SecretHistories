extends Control

enum EscMenuButtons {
	RESUME,
	SAVE,
	SETTINGS,
	QUIT
}

func exit_state():
	self.visible = false
	pass

func enter_state():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	self.visible = true
	pass


signal button_pressed(button)

func _on_ResumeButton_pressed() -> void:
	emit_signal("button_pressed", EscMenuButtons.RESUME)
#	get_parent().get_parent().esc_menu_active = false #not tested
#	get_tree().paused = not get_tree().paused
#	$ColorRect.visible = get_tree().paused
##	get_tree().set_input_as_handled()
#	hide()

func _on_SaveButton_pressed() -> void:
	emit_signal("button_pressed", EscMenuButtons.SAVE)


func _on_SettingsButton_pressed():
	emit_signal("button_pressed", EscMenuButtons.SETTINGS)
#	$"../SettingsMenu".show()
#	call_deferred("hide")


func _on_QuitButton_pressed() -> void:
	emit_signal("button_pressed", EscMenuButtons.QUIT)
#	get_tree().quit()


func _input(event):
	if event.is_action_pressed("fullscreen"):
		if not VideoSettings.is_fullscreen_enabled():
			VideoSettings.set_fullscreen_enabled(true)

