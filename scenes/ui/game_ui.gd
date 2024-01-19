extends CanvasLayer


enum GUIState {
	HUD,
	PAUSE
}

var gui_state : int = GUIState.HUD: set = set_gui_state

@onready var states = [
	%HUD,
	%PauseMenu
]

@onready var hud_root = %HUD


func set_gui_state(value : int):
	states[gui_state].exit_state()
	gui_state = value
	states[gui_state].enter_state()


func _ready():
	for state in states:
		state.exit_state()
	states[gui_state].enter_state()
	self.scale = Vector2.ONE*VideoSettings.gui_scale
	%UIRoot.size = get_viewport().size/VideoSettings.gui_scale
	VideoSettings.connect("gui_scale_changed", Callable(self, "on_gui_scale_changed"))


func on_gui_scale_changed(value):
	self.scale = Vector2.ONE*value


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc_menu") and not GameManager.is_player_dead:
		match gui_state:
			GUIState.HUD:
				self.gui_state = GUIState.PAUSE
				get_viewport().set_input_as_handled()
			GUIState.PAUSE:
				self.gui_state = GUIState.HUD
				get_viewport().set_input_as_handled()
