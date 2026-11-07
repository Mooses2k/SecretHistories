extends GutTest

## Pins the back-navigation ruling (#606 owner playtest): RMB never leaves
## the settings menu (it must stay free for rebinding), keyboard Escape
## still does, and Escape during an armed capture only cancels the capture.

const SETTINGS_MENU_SCENE := "res://scenes/ui/settings_menu.tscn"

var menu : Control


func before_each() -> void:
	menu = (load(SETTINGS_MENU_SCENE) as PackedScene).instantiate()
	add_child_autofree(menu)
	menu.visible = true


func _escape_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	return event


func _rmb_event(pressed : bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	return event


func test_rmb_does_not_close_the_settings_menu() -> void:
	menu._unhandled_input(_rmb_event(true))
	assert_true(menu.visible, "RMB press does not back out of settings")
	menu._unhandled_input(_rmb_event(false))
	assert_true(menu.visible, "RMB release does not back out either")


func test_escape_still_closes_the_settings_menu() -> void:
	var exited := [false]
	menu.settings_menu_exited.connect(func() -> void: exited[0] = true)
	menu._unhandled_input(_escape_event())
	assert_false(menu.visible, "Escape closes the settings menu")
	assert_true(exited[0], "the exited signal still fires")


func test_escape_during_capture_only_cancels_the_capture() -> void:
	# Armed capture: the string editor consumes Escape in _input before the
	# menu sees it, so one Escape must not both cancel capture and exit.
	var panel: Control = menu.get_node("ChangeKeyPanel")
	panel.show()
	var exited := [false]
	menu.settings_menu_exited.connect(func() -> void: exited[0] = true)
	menu._unhandled_input(_escape_event())
	assert_true(menu.visible, "the menu stays open during capture")
	assert_false(exited[0], "no menu exit while the capture panel is up")
	panel.hide()
