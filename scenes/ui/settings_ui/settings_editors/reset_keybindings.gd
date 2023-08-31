extends Node


func toggle_panel():
	if self.visible:
		get_node(".").hide()
	else:
		get_node(".").show()


func _on_Yes_pressed():
	Settings.set_setting(KeybindingManager.keys_default.keys()[3], "all")
	toggle_panel() 


func _on_No_pressed():
	toggle_panel()
