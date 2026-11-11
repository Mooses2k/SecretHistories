extends CanvasLayer
class_name GameUI

const TinnitusOverlay := preload("res://scenes/ui/tinnitus_overlay.gd")
const BloodScreenOverlay := preload("res://scenes/ui/blood_screen_overlay.gd")
const DeathScreen := preload("res://scenes/ui/death_screen.gd")
const HelpOverlay := preload("res://scenes/ui/help_overlay.gd")
# No class_name on the death cam: headless runs never refresh the global
# class cache, so the preload path is the only reliable handle.
const DeathCamScript := preload("res://scenes/characters/player/death_cam.gd")


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
@onready var _blood_screen : BloodScreenOverlay = %BloodScreen
@onready var _death_screen : DeathScreen = %DeathScreen
@onready var _help_info : HelpOverlay = %HelpInfo

var _observed_player : Node = null
var _observed_state : HumanoidCharacterState = null
var _observed_hurtboxes : Array[Hurtbox] = []


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
	_death_screen.fade_out_started.connect(_on_death_screen_fade_out)
	var game := get_parent()
	if game != null and game.has_signal("player_spawned"):
		game.connect("player_spawned", _on_game_player_spawned)


func _exit_tree() -> void:
	if Events.is_connected("tinnitus_triggered", _on_Events_tinnitus_triggered):
		Events.disconnect("tinnitus_triggered", _on_Events_tinnitus_triggered)
	if _death_screen.fade_out_started.is_connected(_on_death_screen_fade_out):
		_death_screen.fade_out_started.disconnect(_on_death_screen_fade_out)
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
	# Every hurtbox reports its own damage events; the overlay reads the
	# decremented State.durability afterwards (State connected first at ready).
	for node in player.find_children("*", "Hurtbox", true, false):
		var hurtbox := node as Hurtbox
		if hurtbox != null:
			hurtbox.damaged.connect(_on_player_hurtbox_damaged)
			_observed_hurtboxes.append(hurtbox)


func _stop_observing_player() -> void:
	if _observed_state != null and is_instance_valid(_observed_state):
		_observed_state.physical_state_changed.disconnect(_on_player_physical_state_changed)
	for hurtbox in _observed_hurtboxes:
		if is_instance_valid(hurtbox) and hurtbox.damaged.is_connected(_on_player_hurtbox_damaged):
			hurtbox.damaged.disconnect(_on_player_hurtbox_damaged)
	_observed_hurtboxes.clear()
	_observed_state = null
	_observed_player = null


func on_gui_scale_changed(value):
	self.scale = Vector2.ONE*value


func _on_game_player_spawned(player : Node) -> void:
	observe_player(player)
	_help_info.set_player(player)


func _on_Events_tinnitus_triggered(strength : float) -> void:
	_tinnitus.trigger(strength)


func _on_player_physical_state_changed(new_physical_state : int) -> void:
	if new_physical_state == HumanoidCharacterState.PhysicalState.DEAD:
		# The physical state change can arrive from inside a physics flush
		# (Area3D damage signals); the death cam reparenting must wait for a
		# safe point in the frame.
		_start_death_flow.call_deferred()


## The death flow: spawn the issue 414 death cam, ring the ears, own the
## picture, then run the death screen sequence.
func _start_death_flow() -> void:
	_start_death_cam()
	# Issue 414: death rings the ears (the tinnitus side of the "silence
	# or tinnitus" pair); the death screen owns the picture from here on,
	# so the white wash yields to it while the ring keeps sounding.
	_tinnitus.trigger(1.0)
	_tinnitus.set_white_wash_hidden(true)
	_blood_screen.set_dead()
	_death_screen.start_sequence()


func _on_death_screen_fade_out() -> void:
	_tinnitus.set_dead()


## Spawns the issue 414 death cam on the dead player: the FPS camera mounts
## to the head bone and rides the ragdoll down. Idempotent.
func _start_death_cam() -> void:
	if _observed_player == null or _observed_player.has_node("DeathCam"):
		return
	var death_cam : Node = DeathCamScript.new()
	death_cam.name = "DeathCam"
	_observed_player.add_child(death_cam)
	death_cam.call("setup", _observed_player)


## Dead-state mouse motion is the slow heavy head look: forwarded to the
## death cam, which damps and clamps it to a tiny range.
func _forward_death_look(event : InputEventMouseMotion) -> void:
	if _observed_player == null:
		return
	var death_cam : Node = _observed_player.get_node_or_null("DeathCam")
	if death_cam != null:
		death_cam.call("apply_death_look", event.relative)


func _on_player_hurtbox_damaged(_amount : int, _type : GlobalConsts.AttackTypes, _direction : Vector3, _origin : Vector3) -> void:
	_blood_screen.on_player_hit(_observed_state.durability)


func _input(event: InputEvent) -> void:
	# F1 help overlay: debug feature, available even during load or death.
	if event.is_action_pressed("misc|help_info"):
		_help_info.toggle()
		get_viewport().set_input_as_handled()
		return
	if LoadScene.loading:
		return
	if GameManager.is_player_dead:
		# The death screen consumes its own ESC (any key fades to the title
		# menu); the pause gate must never open over a dead player. Mouse
		# motion while dead is the slow heavy head look of the death cam.
		if event is InputEventMouseMotion:
			_forward_death_look(event)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("esc_menu"):
		match gui_state:
			GUIState.HUD:
				self.gui_state = GUIState.PAUSE
				get_viewport().set_input_as_handled()
			GUIState.PAUSE:
				self.gui_state = GUIState.HUD
				get_viewport().set_input_as_handled()
