extends "string_editor.gd"


## Capture editor for the Gamepad settings tab: binds joypad button presses
## and stick/trigger axis tilts into the joypad slot of one action, with the
## same panel, notice and idle-timeout mechanics as the keyboard string
## editor. Keyboard and mouse events stay ignored here: the Input tab owns
## that slot. The row's Clear button becomes "Defaults": clearing a gamepad
## slot restores the action's project joypad bindings.

const GAMEPAD_CAPTURE_HINT : String = "Press a Pad Button or Move a Stick to Assign..."
const CAPTURE_AXIS_THRESHOLD : float = 0.5


func _capture_hint() -> String:
	return GAMEPAD_CAPTURE_HINT


## Keyboard rows reject joypad input with a notice; the gamepad row
## captures it. Sub-threshold tilts and button releases keep waiting.
func _on_joypad_event_while_waiting(event : InputEvent, change_key_panel : Control) -> void:
	var capture := _capture_pad_event(event)
	if capture == null:
		return
	_stop_capture(change_key_panel)
	settings.set_setting(_setting_name, capture)
	_show_timed_notice(change_key_panel, KeyInputSettings.get_last_conflict_notice())


func _capture_pad_event(event : InputEvent) -> InputEvent:
	if event is InputEventJoypadButton and event.pressed:
		return event
	if event is InputEventJoypadMotion and absf(event.axis_value) >= CAPTURE_AXIS_THRESHOLD:
		return event
	return null


## The joypad slot never binds keyboard or mouse events: they are ignored
## while waiting, and the reserved-key notice does not apply here.
func _capture_event(_event : InputEvent) -> InputEvent:
	return null


func _is_protected_key(_event : InputEvent) -> bool:
	return false
