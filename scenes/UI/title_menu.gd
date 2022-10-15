extends Control


func _ready():
	if LoadQuotes.list2.empty() and LoadQuotes.list1.empty():
		LoadQuotes.load_files()
	
	$VBoxContainer/ContinueButton.grab_focus()


func _on_ContinueButton_pressed():
	pass # Replace with function body once save/load implemented.


#needs work
func _on_StartButton_pressed():
#	get_parent().title_menu_active = false      #doesn't work this stuff
#	get_parent().start_game_menu_active = true
	var _error = get_tree().change_scene("res://scenes/UI/start_game_menu.tscn")


func _on_SettingsButton_pressed():
	$"%SettingsMenu".show()


func _on_CreditsButton_pressed():
	pass # Replace with function body once Credits screen implemented..


func _on_QuitButton_pressed():
	get_tree().quit()
