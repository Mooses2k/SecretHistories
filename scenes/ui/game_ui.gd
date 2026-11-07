extends CanvasLayer
class_name GameUI

const TinnitusOverlay := preload("res://scenes/ui/tinnitus_overlay.gd")


enum GUIState {
	HUD,
	PAUSE
}

var gui_state : int = GUIState.HUD: set = set_gui_state

@onready var states = [
	%HUD,
	%PauseMenu
]

@onready var hud_root : HUD = %HUD
@onready var _tinnitus : TinnitusOverlay = %Tinnitus

var _observed_player : Node = null
var _observed_state : HumanoidCharacterState = null


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
	Events.connect("tinnitus_triggered", _on_Events_tinnitus_triggered)
	var game := get_parent()
	if game != null and game.has_signal("player_spawned"):
		game.connect("player_spawned", _on_game_player_spawned)


func _exit_tree() -> void:
	if Events.is_connected("tinnitus_triggered", _on_Events_tinnitus_triggered):
		Events.disconnect("tinnitus_triggered", _on_Events_tinnitus_triggered)
	_stop_observing_player()


## Starts observing one spawned player's state signals. Idempotent: a floor
## change re-emits player_spawned for the same player and does not rewire.
func observe_player(player : Node) -> void:
	if player == _observed_player:
		return
	_stop_observing_player()
	_observed_player = player
	_observed_state = player.get_node("State") as HumanoidCharacterState
	_observed_state.physical_state_changed.connect(_on_player_physical_state_changed)


func _stop_observing_player() -> void:
	if _observed_state != null and is_instance_valid(_observed_state):
		_observed_state.physical_state_changed.disconnect(_on_player_physical_state_changed)
	_observed_state = null
	_observed_player = null


func on_gui_scale_changed(value):
	self.scale = Vector2.ONE*value


func _on_game_player_spawned(player : Node) -> void:
	observe_player(player)


func _on_Events_tinnitus_triggered(strength : float) -> void:
	_tinnitus.trigger(strength)


func _on_player_physical_state_changed(new_physical_state : int) -> void:
	if new_physical_state == HumanoidCharacterState.PhysicalState.DEAD:
		_tinnitus.set_dead()


func _input(event: InputEvent) -> void:
	if LoadScene.loading:
		return
	if event.is_action_pressed("esc_menu") and not GameManager.is_player_dead:
		match gui_state:
			GUIState.HUD:
				self.gui_state = GUIState.PAUSE
				get_viewport().set_input_as_handled()
			GUIState.PAUSE:
				self.gui_state = GUIState.HUD
				get_viewport().set_input_as_handled()
