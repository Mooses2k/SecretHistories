extends CanvasLayer

enum GUIState {
	HUD,
	PAUSE
}

onready var states = [
	$"%HUD",
	$"%PauseMenu"
]

var gui_state : int = GUIState.HUD setget set_gui_state

func set_gui_state(value : int):
	states[gui_state].exit_state()
	gui_state = value
	states[gui_state].enter_state()
		
func _ready():
	for state in states:
		state.exit_state()
	states[gui_state].enter_state()
	self.scale = Vector2.ONE*VideoSettings.gui_scale
	$"%UIRoot".rect_size = get_viewport().size/VideoSettings.gui_scale
	VideoSettings.connect("gui_scale_changed", self, "on_gui_scale_changed")

func on_gui_scale_changed(value):
	self.scale = Vector2.ONE*value


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		match gui_state:
			GUIState.HUD:
				self.gui_state = GUIState.PAUSE
				get_tree().set_input_as_handled()
			GUIState.PAUSE:
				self.gui_state = GUIState.HUD
				get_tree().set_input_as_handled()
