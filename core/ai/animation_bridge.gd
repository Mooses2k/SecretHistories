class_name AnimationBridge
extends Node

## Consumes the state family's entered/exited/anim_event signals and drives
## the character's CharacterAnimationTree parameters and the character Audio
## node. The brain knows no animation internals: states emit named anim
## events (reload, shot, attack_cut, attack_thrust) and this bridge maps them
## onto the OneShot request parameters and the voice lines.
## Voice mapping (the shared root state names, 3.x parity): Suspicious and
## Investigate entries alert; a Combat entry plays the detection line; the
## first Patrol entry after an Idle wait plays the idle chatter; the reload
## event goes to the reload line hook; the shot event to the fight line.
## attack_cut and attack_thrust are NEVER forwarded: the melee item fires
## its own one-shots, so a bridge forward would double-fire.
## Phase 1 provides the real animation tree and audio node; both may be null
## and the bridge then only records.


const MELEE_ONE_SHOT_EVENTS: Array[StringName] = [&"attack_cut", &"attack_thrust"]


var animation_tree: AnimationTree = null
var audio: Node = null

var last_state_entered: StringName = &""
var last_state_exited: StringName = &""
var last_anim_event: StringName = &""


## Connect every state in the machine (recursively, so sub-machine children
## are covered) to this bridge.
func setup(machine: HFSM, animation_tree_ref: AnimationTree = null, audio_node: Node = null) -> void:
	animation_tree = animation_tree_ref
	audio = audio_node
	for state in machine.get_states_recursive():
		state.entered.connect(_on_state_entered)
		state.exited.connect(_on_state_exited)
		state.anim_event.connect(_on_anim_event)


func _on_state_entered(state_name: StringName) -> void:
	var previous := last_state_entered
	last_state_entered = state_name
	if audio == null:
		return
	match state_name:
		&"Suspicious", &"Investigate":
			if audio.has_method("play_alert_sound"):
				audio.call("play_alert_sound")
		&"Combat":
			if audio.has_method("on_player_detected"):
				audio.call("on_player_detected", null, Vector3.ZERO)
		&"Patrol":
			if previous == &"Idle" and audio.has_method("_on_BT_Wait_Random_character_idled"):
				audio.call("_on_BT_Wait_Random_character_idled")


func _on_state_exited(state_name: StringName) -> void:
	last_state_exited = state_name


func _on_anim_event(anim_name: StringName) -> void:
	last_anim_event = anim_name
	if anim_name in MELEE_ONE_SHOT_EVENTS:
		return
	if audio != null:
		match anim_name:
			&"reload":
				if audio.has_method("_on_reload_ammo_character_reloaded"):
					audio.call("_on_reload_ammo_character_reloaded")
			&"shot":
				if audio.has_method("play_fight_sound"):
					audio.call("play_fight_sound")
	if animation_tree == null:
		return
	animation_tree.set(
		"parameters/%s/request" % anim_name,
		AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	)
