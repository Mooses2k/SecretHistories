# Pins the RESET BUTTON PATH through the real settings menu scene: the
# "Reset" button must actually open the confirmation panel and Yes must
# reset the live bindings. Regression ground: runtime-built settings rows
# have no scene owner, so the old owner-chain lookup silently skipped the
# button-to-panel connection and the owner's Reset did nothing with nothing
# printed (owner report 2026-11-08). The fix resolves the panel by walking
# ancestors from the button. Owner ruling 2026-11-09: the Reset is a compact
# button riding the first binding row to the right of its Change and Clear
# buttons (the old long-named "Reset to defaults" row is gone).
# The real settings_menu.tscn is instantiated (both embed sites instance it:
# title menu and pause menu), rows build through the real attach_settings
# flow, and the live KeyInputSettings autoload is what gets reset.
extends GutTest

const SETTINGS_MENU_SCENE := "res://scenes/ui/settings_menu.tscn"


func _find_reset_button(root : Node) -> Button:
	# The reset button rides the first binding row, to the right of that
	# row's Change and Clear buttons; ResetPanel's own Yes/No buttons must
	# not match.
	var stack : Array[Node] = [root]
	while not stack.is_empty():
		var node : Node = stack.pop_back()
		if node is Button and (node as Button).text == "Reset" \
				and _row_has_change_and_clear(node.get_parent()):
			return node as Button
		stack.append_array(node.get_children())
	return null


func _row_has_change_and_clear(row : Node) -> bool:
	if row == null:
		return false
	var change := false
	var clear := false
	for child in row.get_children():
		if child is Button:
			if (child as Button).text == "Change":
				change = true
			elif (child as Button).text == "Clear":
				clear = true
	return change and clear


func test_reset_button_opens_the_panel_and_yes_resets_the_live_map() -> void:
	var menu : Control = (load(SETTINGS_MENU_SCENE) as PackedScene).instantiate()
	add_child_autofree(menu)
	menu.visible = true

	# The regression: the button must be CONNECTED (the old owner-chain
	# lookup silently skipped the connection).
	var button := _find_reset_button(menu)
	assert_not_null(button, "the first binding row carries the Reset button")
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
