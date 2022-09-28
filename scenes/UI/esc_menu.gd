extends Popup


func _ready():
	pass # Replace how to close this menu.


func _on_ResumeButton_pressed() -> void:
	get_parent().get_parent().esc_menu_active = false #not tested
	get_tree().paused = not get_tree().paused
	$ColorRect.visible = get_tree().paused
#	get_tree().set_input_as_handled()
	hide()


func _on_SettingsButton_pressed():
	$"../SettingsMenu".popup()


func _on_QuitButton_pressed() -> void:
	#add an 'are you sure?' here
	get_tree().quit()
