# Pins the RESET BUTTON PATH through the real settings menu scene: the
# "Reset keybindings" button must actually open the confirmation panel and
# Yes must reset the live bindings. Regression ground: runtime-built settings
# rows have no scene owner, so the old owner-chain lookup silently skipped
# the button-to-panel connection and the owner's Reset did nothing with
# nothing printed (owner report 2026-11-08). The fix resolves the panel by
# walking ancestors from the button.
# The real settings_menu.tscn is instantiated (both embed sites instance it:
# title menu and pause menu), rows build through the real attach_settings
# flow, and the live KeyInputSettings autoload is what gets reset.
extends GutTest

const SETTINGS_MENU_SCENE := "res://scenes/ui/settings_menu.tscn"
const RESET_EDITOR_SCRIPT := preload("res://scenes/ui/settings_ui/settings_editors/reset_keybindings.gd")


func _find_reset_editor(root : Node) -> Node:
	var stack : Array[Node] = [root]
	while not stack.is_empty():
		var node : Node = stack.pop_back()
		if node.get_script() == RESET_EDITOR_SCRIPT:
			return node
		stack.append_array(node.get_children())
	return null


func _find_reset_button(root : Node) -> Button:
	# The reset button is the set_default_keys editor row (text "   Reset to
	# defaults   "); ResetPanel's own Yes/No buttons must not match.
	var stack : Array[Node] = [root]
	while not stack.is_empty():
		var node : Node = stack.pop_back()
		if node is Button and str((node as Button).text).strip_edges() == "Reset to defaults":
			return node as Button
		stack.append_array(node.get_children())
	return null


func test_reset_button_opens_the_panel_and_yes_resets_the_live_map() -> void:
	var menu : Control = (load(SETTINGS_MENU_SCENE) as PackedScene).instantiate()
	add_child_autofree(menu)
	menu.visible = true

	var editor := _find_reset_editor(menu)
	assert_not_null(editor, "the settings menu builds the reset editor row")

	# The regression: the button must be CONNECTED (the old owner-chain
	# lookup silently skipped the connection).
	var button := _find_reset_button(menu)
	assert_not_null(button, "the reset editor carries its Button")
	assert_gt(button.get_signal_connection_list("pressed").size(), 0,
		"the reset button is connected to the panel (no silent no-op)")

	var panel : Control = menu.get_node("ResetPanel") as Control
	assert_false(panel.visible, "the confirmation panel starts hidden")

	button.pressed.emit()
	assert_true(panel.visible, "pressing the reset button opens the panel")

	# Corrupt the live crouch binding so the reset has something to undo:
	# strip any default-looking Ctrl/C events, add a wrong one. The action
	# may legitimately carry zero events at test start, so no [0] indexing.
	var theft := InputEventKey.new()
	theft.physical_keycode = KEY_S
	InputMap.action_add_event("player|crouch", theft)
	for ev in InputMap.action_get_events("player|crouch"):
		var key := ev as InputEventKey
		if key != null and (key.physical_keycode == KEY_C or key.physical_keycode == KEY_CTRL):
			InputMap.action_erase_event("player|crouch", key)
	var still_default := false
	for ev in InputMap.action_get_events("player|crouch"):
		var key := ev as InputEventKey
		if key != null and (key.physical_keycode == KEY_C or key.physical_keycode == KEY_CTRL):
			still_default = true
	assert_false(still_default, "precondition: crouch is corrupted away from its defaults")

	var yes : Button = panel.get_node("Yes") as Button
	yes.pressed.emit()

	# Project default events are keycode-based (probe: as_text "Ctrl"/"C",
	# physical 0), so match on keycode, not physical_keycode.
	var events := InputMap.action_get_events("player|crouch")
	var has_default_crouch := false
	for ev in events:
		var key := ev as InputEventKey
		if key != null and (key.keycode == KEY_C or key.keycode == KEY_CTRL):
			has_default_crouch = true
	assert_true(has_default_crouch, "Yes resets the live crouch binding from project.godot")
	assert_false(panel.visible, "Yes closes the confirmation panel")
