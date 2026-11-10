class_name AnimationBridge
extends Node

## Consumes the state family's entered/exited/anim_event signals and drives
## the character's CharacterAnimationTree parameters and the character Audio
## node. The brain knows no animation internals: states emit named anim
## events (reload, attack_cut, attack_thrust) and this bridge maps them onto
## the OneShot request parameters. Phase 1 provides the real animation tree
## and audio node; both may be null and the bridge then only records.


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
	last_state_entered = state_name


func _on_state_exited(state_name: StringName) -> void:
	last_state_exited = state_name


func _on_anim_event(anim_name: StringName) -> void:
	last_anim_event = anim_name
	if animation_tree == null:
		return
	animation_tree.set(
		"parameters/%s/request" % anim_name,
		AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	)
