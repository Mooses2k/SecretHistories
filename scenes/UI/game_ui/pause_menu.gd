extends MarginContainer


onready var esc_menu = $EscMenu

enum PauseMenuState {
	ESC_MENU,
	SETTINGS_MENU
}

onready var states = [
	$EscMenu,
	$SettingsMenu
]

var gui_state = PauseMenuState.ESC_MENU setget set_gui_state


func _ready() -> void:
	for state in states:
		state.exit_state()
	states[gui_state].enter_state()


func set_gui_state(value : int):
	states[gui_state].exit_state()
	gui_state = value
	states[gui_state].enter_state()


func exit_state():
	get_tree().paused = false
	self.gui_state = PauseMenuState.ESC_MENU
	self.visible = false
	pass


func enter_state():
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	self.visible = true
	pass


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not GameManager.is_player_dead:
		match gui_state:
			PauseMenuState.SETTINGS_MENU:
				self.gui_state = PauseMenuState.ESC_MENU
				get_tree().set_input_as_handled()


func _on_EscMenu_button_pressed(button) -> void:
	match button:
		esc_menu.EscMenuButtons.RESUME:
			owner.gui_state = owner.GUIState.HUD
		esc_menu.EscMenuButtons.SAVE:
			print_debug("Saving not yet implemented")
			
		esc_menu.EscMenuButtons.SETTINGS:
			self.gui_state = PauseMenuState.SETTINGS_MENU

		esc_menu.EscMenuButtons.QUIT:
			get_tree().quit()

	pass # Replace with function body.


func _on_SettingsMenu_settings_menu_exited() -> void:
	self.gui_state = PauseMenuState.ESC_MENU
	pass # Replace with function body.
