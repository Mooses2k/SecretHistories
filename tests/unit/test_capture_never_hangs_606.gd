extends GutTest

## Pins the capture never-hangs contract (#606 owner playtest): the capture
## panel assigns on keyboard (lone modifiers included) and mouse presses,
## Escape always cancels, a stale notice or idle timer from a finished
## capture never resurrects a hidden panel, and an idle capture times out
## cleanly with a notice.

const KICK := "kick"
const OFFHAND_USE := "playerhand|offhand_use"

var holder : Node
var editor : Node
var panel : Control
var offhand_use_events : Array = []


func before_each() -> void:
	InputMap.action_erase_events(KICK)
	offhand_use_events = InputMap.action_get_events(OFFHAND_USE).duplicate()
	holder = Node.new()
	add_child_autofree(holder)
	panel = Panel.new()
	panel.name = "ChangeKeyPanel"
	var label := Label.new()
	label.name = "Label"
	panel.add_child(label)
	holder.add_child(panel)
	var editor_scene: PackedScene = load(
			"res://scenes/ui/settings_ui/settings_editors/string_editor.tscn")
	editor = editor_scene.instantiate()
	holder.add_child(editor)
	editor.attach_setting(KICK, Settings)


func after_each() -> void:
	InputMap.action_erase_events(KICK)
	for event in offhand_use_events:
		var restored := event as InputEvent
		if restored:
			InputMap.action_add_event(OFFHAND_USE, restored)
	KeybindingManager.save_keys()


func _key_event(keycode : Key, pressed : bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	return event


func _arm_capture() -> void:
	panel.visible = false
	editor._on_Change_pressed()
	assert_true(panel.visible, "precondition: capture panel armed")


func _panel_label_text() -> String:
	return (panel.get_node("Label") as Label).text


func test_lone_modifier_press_binds_like_any_key() -> void:
	_arm_capture()
	editor._input(_key_event(KEY_ALT))
	assert_false(editor.is_waiting_input, "the Alt press completed the capture")
	# Alt is also the Offhand Use default, so the binding reports the
	# conflict in the panel and the panel hides when the notice expires.
	assert_true(panel.visible, "the conflict notice shows in the capture panel")
	assert_true(_panel_label_text().contains("taken from"),
			"the notice names the row that lost Alt")
	var ids := PackedStringArray()
	for event in InputMap.action_get_events(KICK):
		ids.append(KeyInputSettings._event_binding_id(event))
	assert_true(ids.has(KeyInputSettings._event_binding_id(_key_event(KEY_ALT))),
			"Alt is now the kick binding")


func test_clean_capture_hides_the_panel_immediately() -> void:
	_arm_capture()
	editor._input(_key_event(KEY_P))
	assert_false(editor.is_waiting_input, "the press completed the capture")
	assert_false(panel.visible, "a conflict-free binding hides the panel")


func test_modifier_combo_press_binds_with_its_modifiers() -> void:
	_arm_capture()
	var combo := _key_event(KEY_W)
	combo.alt_pressed = true
	editor._input(combo)
	var ids := PackedStringArray()
	for event in InputMap.action_get_events(KICK):
		ids.append(KeyInputSettings._event_binding_id(event))
	assert_true(ids.has(KeyInputSettings._event_binding_id(combo)),
			"the combo binds with its modifier state")


func test_escape_cancels_capture_without_binding() -> void:
	_arm_capture()
	editor._input(_key_event(KEY_ESCAPE))
	assert_false(editor.is_waiting_input, "Escape cancels capture")
	assert_false(panel.visible, "the panel hides on cancel")
	assert_true(InputMap.action_get_events(KICK).is_empty(),
			"no binding happened")


func test_unbindable_events_are_explicitly_ignored() -> void:
	_arm_capture()
	var motion := InputEventMouseMotion.new()
	editor._input(motion)
	assert_true(editor.is_waiting_input, "mouse motion keeps capture armed")
	var release := _key_event(KEY_K, false)
	editor._input(release)
	assert_true(editor.is_waiting_input, "a key release is ignored, not assigned")


func test_protected_keys_are_rejected_and_capture_stays_armed() -> void:
	_arm_capture()
	editor._input(_key_event(KEY_QUOTELEFT))
	assert_true(editor.is_waiting_input, "backquote does not complete the capture")
	assert_true(_panel_label_text().contains("reserved"),
			"the notice says backquote and F1 are reserved")
	editor._input(_key_event(KEY_F1))
	assert_true(editor.is_waiting_input, "F1 does not complete the capture either")
	assert_true(InputMap.action_get_events(KICK).is_empty(),
			"no protected key was bound")
	# apply_binding refuses them directly too, whatever path feeds it.
	KeyInputSettings.apply_binding(KICK, _key_event(KEY_QUOTELEFT))
	KeyInputSettings.apply_binding(KICK, _key_event(KEY_F1))
	assert_true(InputMap.action_get_events(KICK).is_empty(),
			"apply_binding refuses protected keys as well")
	# The capture is still armed afterwards and a normal key binds.
	editor._input(_key_event(KEY_P))
	assert_false(editor.is_waiting_input, "a normal key still completes the capture")


func test_idle_timeout_cancels_capture_with_a_notice() -> void:
	_arm_capture()
	editor._on_capture_idle_timeout(editor._capture_generation)
	assert_false(editor.is_waiting_input, "the idle timeout cancels capture")
	assert_eq(_panel_label_text(), "Capture timed out: no key assigned",
			"the timeout notice explains the cancel")


func test_stale_timers_never_resurrect_a_hidden_panel() -> void:
	_arm_capture()
	var stale_generation: int = editor._capture_generation
	editor._input(_key_event(KEY_ESCAPE))
	assert_false(panel.visible, "panel hidden by cancel")
	editor._on_capture_idle_timeout(stale_generation)
	assert_false(panel.visible, "a stale idle timer does not reopen the panel")
	assert_false(editor.is_waiting_input, "no phantom capture")


func test_second_capture_supersedes_a_pending_notice_timer() -> void:
	# Simulate the old sticky-panel bug: a notice timer from a finished
	# capture firing while a new capture is armed must not touch it.
	_arm_capture()
	var notice_generation: int = editor._capture_generation
	editor._input(_key_event(KEY_ESCAPE))
	_arm_capture()
	editor._on_notice_timer_timeout(notice_generation)
	assert_true(panel.visible, "the new capture keeps its panel")
	assert_true(editor.is_waiting_input, "the new capture stays armed")
	assert_eq(_panel_label_text(), "Press Key or Mouse Button to Assign...",
			"the hint text is untouched")
