class_name AIState
extends Node

## Base class for every HFSM state node. States are fat and few: they write
## movement and facing intents, run their own timers, and declare a transition
## table the runner evaluates every tick. The intent contract mirrors the old
## CharacterState: normalized, y-flattened move_direction the controller
## copies into the character input every physics frame.


signal entered(state_name: StringName)
signal exited(state_name: StringName)
signal anim_event(anim_name: StringName)


## One transition-table row: jump to `to_state` when the bool-returning guard
## method named `guard` on this state passes. An empty guard always passes.
## Priority is the array order: the first passing row wins.
class Transition extends Resource:
	@export var to_state: StringName = &""
	@export var guard: StringName = &""


@export var transitions: Array[Transition] = []

## The root machine this state belongs to; carries the blackboard, the
## navigation adapter and the shared RNG.
var brain: HFSM = null

var move_direction := Vector3.ZERO: set = set_move_direction
var face_direction := Vector3.FORWARD: set = set_face_direction


## Called by the runner after exit of the previous state.
func enter() -> void:
	move_direction = Vector3.ZERO


## Called by the runner before enter of the next state.
func exit() -> void:
	move_direction = Vector3.ZERO


## Called on the active state every machine tick, after the transition
## evaluation.
func tick(_delta: float) -> void:
	pass


func board() -> Blackboard:
	if brain != null:
		return brain.blackboard
	return null


func character_position() -> Vector3:
	if brain != null and brain.navigation != null and brain.navigation.character != null:
		return brain.navigation.character.global_position
	return Vector3.ZERO


func current_target() -> Object:
	var current_board := board()
	if current_board != null:
		return current_board.target
	return null


func has_target() -> bool:
	var current := current_target()
	return current != null and is_instance_valid(current)


func current_target_position() -> Vector3:
	if not has_target():
		return Vector3.ZERO
	var node := current_target() as Node3D
	if node == null:
		return Vector3.ZERO
	if node.is_inside_tree():
		return node.global_position
	return node.position


func distance_to_target() -> float:
	if not has_target():
		return INF
	return character_position().distance_to(current_target_position())


## Guards: the small fixed set every state can use in its table. States add
## their own typed guard methods alongside these.


func guard_always() -> bool:
	return true


func guard_never() -> bool:
	return false


func guard_is_dead() -> bool:
	var current_board := board()
	return current_board != null and current_board.dead


func guard_alert_at_least_investigate() -> bool:
	var current_board := board()
	return current_board != null and current_board.alert_reaches_investigate()


func guard_alert_below_investigate() -> bool:
	var current_board := board()
	return current_board == null or not current_board.alert_reaches_investigate()


func guard_alert_at_least_combat() -> bool:
	var current_board := board()
	return current_board != null and current_board.alert_reaches_combat()


func guard_has_target() -> bool:
	return has_target()


func guard_no_target() -> bool:
	return not has_target()


## Combat needs a target AND combat-level alertness; a loud noise alone must
## never open fire.
func guard_can_fight() -> bool:
	return has_target() and guard_alert_at_least_combat()


func guard_weapon_gun() -> bool:
	var current_board := board()
	return current_board != null and current_board.weapon_mode == Blackboard.WeaponMode.GUN


func guard_weapon_melee() -> bool:
	var current_board := board()
	return current_board != null and current_board.weapon_mode == Blackboard.WeaponMode.MELEE


func set_move_direction(value: Vector3) -> void:
	var flat := Vector3(value.x, 0.0, value.z)
	move_direction = flat.normalized() * minf(flat.length(), 1.0)


func set_face_direction(value: Vector3) -> void:
	var flat := Vector3(value.x, 0.0, value.z)
	if not flat.is_equal_approx(Vector3.ZERO):
		face_direction = flat.normalized()
