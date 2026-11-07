extends "setting_editor.gd"


## Hint shown while the capture panel waits for a binding.
const CAPTURE_HINT : String = "Press Key or Mouse Button to Assign..."
const CONFLICT_NOTICE_SECONDS : float = 2.5

var is_waiting_input : bool = false


# Override this function
func _get_value():
	return str(%Value.text)


# Override this function
func _set_value(value):
	%Value.text = ""
	if value == null:
		return

	for event in value:
		%Value.text += event
		if value.find(event) != (value.size() - 1):
			%Value.text += ", "


# Override this function
func _on_value_edited():
	var new_value = get_value()
	if new_value != settings.get_setting(_setting_name):
		settings.set_setting(_setting_name, new_value)


# Override this function
func _on_setting_attached():
#	%Value.connect("value_changed", self, "on_value_edited")
	_apply_name_text()


## A keybinding row carries a display_name meta from the declarative map.
## Without one, fall back to the text after the action's namespace pipe, or
## the raw name for pipe-less actions like hotbar_1.
func _apply_name_text():
	var display_name = settings.get_setting_meta(_setting_name, "display_name")
	if display_name is String and not display_name.is_empty():
		%Name.text = display_name
	elif _setting_name.contains('|'):
		%Name.text = _setting_name.get_slice('|', 1).capitalize()
	else:
		%Name.text = _setting_name.capitalize()


func _on_Value_value_changed(value):
	on_value_edited()


## One capture path for every row: keyboard keys and mouse buttons bind,
## Escape cancels, everything else is swallowed while waiting.
func _input(event):
	var change_key_panel := _find_change_key_panel()
	if change_key_panel and not change_key_panel.visible:
		is_waiting_input = false
	if not is_waiting_input:
		return
	get_viewport().set_input_as_handled()
	if _is_cancel_event(event):
		_stop_capture(change_key_panel)
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_show_panel_notice(change_key_panel, "Gamepad capture is not supported yet")
		return
	var capture := _capture_event(event)
	if capture == null:
		return
	_stop_capture(change_key_panel)
	settings.set_setting(_setting_name, capture)
	_show_conflict_notice(change_key_panel, KeyInputSettings.get_last_conflict_notice())


func _capture_event(event : InputEvent) -> InputEvent:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		return event
	if event is InputEventMouseButton and event.is_pressed():
		return event
	return null


func _is_cancel_event(event : InputEvent) -> bool:
	return event is InputEventKey and event.is_pressed() \
			and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE)


func _stop_capture(change_key_panel : Control) -> void:
	is_waiting_input = false
	if change_key_panel:
		change_key_panel.hide()


## Helper function to find the ChangeKeyPanel node robustly
func _find_change_key_panel() -> Control:
	# First try to find it in the scene tree by name
	var scene_root = get_tree().current_scene
	if scene_root:
		var panel = scene_root.find_child("ChangeKeyPanel", true, false)
		if panel:
			return panel
	
	# Fallback: traverse up the tree looking for a node with ChangeKeyPanel
	var current_node = self
	while current_node:
		if current_node.has_node("ChangeKeyPanel"):
			return current_node.get_node("ChangeKeyPanel")
		current_node = current_node.get_parent()
	
	return null


func _on_Clear_pressed():
	settings.set_setting(_setting_name, null)


func _on_Change_pressed():
	var change_key_panel := _find_change_key_panel()
	if change_key_panel:
		_show_panel_notice(change_key_panel, CAPTURE_HINT)
		is_waiting_input = true
	else:
		print("Warning: ChangeKeyPanel not found")


## Show a notice in the capture panel without changing capture state.
func _show_panel_notice(change_key_panel : Control, notice : String) -> void:
	var label := change_key_panel.get_node_or_null("Label") as Label
	if label:
		label.text = notice
	change_key_panel.show()


## After a binding that cleared a conflict, surface why the other row lost
## its key, then restore the panel to its resting state.
func _show_conflict_notice(change_key_panel : Control, notice : String) -> void:
	if notice.is_empty() or change_key_panel == null:
		return
	_show_panel_notice(change_key_panel, notice)
	var timer := get_tree().create_timer(CONFLICT_NOTICE_SECONDS)
	timer.timeout.connect(_on_notice_timer_timeout.bind(change_key_panel))


func _on_notice_timer_timeout(change_key_panel : Control) -> void:
	if is_waiting_input:
		return
	_stop_capture(change_key_panel)
	_show_panel_notice(change_key_panel, CAPTURE_HINT)
