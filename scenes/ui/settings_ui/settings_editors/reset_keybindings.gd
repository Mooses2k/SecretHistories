extends Node


## Asks for confirmation, then resets all mapped keybindings through the
## key settings autoload: one reset path, straight from project.godot.

func toggle_panel():
	if self.visible:
		get_node(".").hide()
	else:
		get_node(".").show()


func _on_Yes_pressed():
	KeyInputSettings.reset_actions()
	toggle_panel()


func _on_No_pressed():
	toggle_panel()
