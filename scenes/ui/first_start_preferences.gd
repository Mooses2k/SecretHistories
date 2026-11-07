extends Control
class_name FirstStartPreferences


## One-time first-start preference prompt (wiki Interface 5.2, issue #606):
## "Because of how many keys are used up by this, like Interact, it'd be
## worthwhile to ask player on first start game which they'd prefer."
## Shown by the brightness calibration flow on the first game start; asks
## crouch hold-vs-toggle and left-hand mouse, and points at the separate
## Kick/Interact/ADS rows. Choices are plain settings writes through the
## sanctioned settings flow, so they persist like any menu change.
## The state machine (choose_* + confirm_choices) is headless-testable; the
## buttons are the only UI wiring.

const SETTING_CROUCH : String = "Hold Crouch"

const TITLE_TEXT : String = "First start preferences"
const BODY_TEXT : String = "A few controls ask what suits your hands. You can change all of these later in Settings."
const CROUCH_TEXT : String = "Crouch: hold the key down, or press to toggle?"
const LEFT_HAND_TEXT : String = "Left-hand mouse? Swaps the mouse buttons: left becomes interact, right fires."
const POINT_TEXT : String = "Kick, Interact and ADS also have separate keys: Settings > Input > Input Key Settings."
const HOLD_LABEL : String = "Hold"
const TOGGLE_LABEL : String = "Toggle"
const YES_LABEL : String = "Yes"
const NO_LABEL : String = "No"
const DONE_LABEL : String = "Done"

# Choice state, defaults matching the settings defaults (crouch is hold, i.e.
# toggle off; left-hand mouse off).
var crouch_hold_chosen : bool = false
var left_hand_chosen : bool = false
var confirmed : bool = false


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.8)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(panel)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(420.0, 0.0)
	panel.add_child(box)

	var title := Label.new()
	title.name = "Title"
	title.text = TITLE_TEXT
	box.add_child(title)

	var body := Label.new()
	body.name = "Body"
	body.text = BODY_TEXT
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)

	var crouch_label := Label.new()
	crouch_label.text = CROUCH_TEXT
	crouch_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(crouch_label)
	var crouch_row := HBoxContainer.new()
	box.add_child(crouch_row)
	crouch_row.add_child(_choice_button("CrouchHold", HOLD_LABEL, choose_crouch_hold.bind(true)))
	crouch_row.add_child(_choice_button("CrouchToggle", TOGGLE_LABEL, choose_crouch_hold.bind(false)))

	var left_label := Label.new()
	left_label.text = LEFT_HAND_TEXT
	left_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(left_label)
	var left_row := HBoxContainer.new()
	box.add_child(left_row)
	left_row.add_child(_choice_button("LeftHandYes", YES_LABEL, choose_left_hand.bind(true)))
	left_row.add_child(_choice_button("LeftHandNo", NO_LABEL, choose_left_hand.bind(false)))

	var point := Label.new()
	point.name = "Point"
	point.text = POINT_TEXT
	point.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(point)

	var done := Button.new()
	done.name = "Done"
	done.text = DONE_LABEL
	done.pressed.connect(confirm_choices)
	box.add_child(done)


func _choice_button(button_name : String, label : String, handler : Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = label
	button.pressed.connect(handler)
	return button


func show_dialog() -> void:
	crouch_hold_chosen = GameSettings.crouch_hold_enabled
	left_hand_chosen = KeyInputSettings.get_left_hand_mouse()
	confirmed = false
	visible = true


## Crouch hold-vs-toggle choice (the existing Hold Crouch mode setting).
func choose_crouch_hold(hold : bool) -> void:
	crouch_hold_chosen = hold


## Left-hand mouse yes/no (the swap setting).
func choose_left_hand(enabled : bool) -> void:
	left_hand_chosen = enabled


## Apply the chosen values through the sanctioned settings flow and close.
func confirm_choices() -> void:
	GameSettings.set_crouch_hold(crouch_hold_chosen)
	KeyInputSettings.set_left_hand_mouse(left_hand_chosen)
	confirmed = true
	visible = false
