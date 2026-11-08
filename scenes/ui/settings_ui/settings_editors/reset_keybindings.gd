class_name ResetKeybindingsEditor
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


## Runtime-built settings rows have no scene owner, so resolving the panel
## through the node owner chain silently fails there (the owner reported the
## reset button doing nothing). Walk the ancestors instead: ResetPanel is a
## direct child of the settings menu root that hosts the settings content.
static func find_panel(from : Node) -> Node:
	var node : Node = from
	while node != null:
		if node.has_node("ResetPanel"):
			return node.get_node("ResetPanel")
		node = node.get_parent()
	return null
