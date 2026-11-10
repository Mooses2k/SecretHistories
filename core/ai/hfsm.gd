class_name HFSM
extends AIState

## The HFSM runner. Holds the child state nodes, evaluates the active state's
## transition table EVERY tick in declared priority order, and switches
## states by calling exit then enter. Guards run even while the active state
## is mid-action, which is the structural fix for the behavior tree's
## ignored-stimulus failure mode (issue #450): a new sight stimulus interrupts
## a goto on the next tick instead of waiting for the action to finish.
## A sub-machine is an HFSM nested as a state: its parent treats it as one
## state while it runs its own table underneath. Lifecycle signals are
## emitted after their method completes, so nested entry and exit announce
## innermost first: exiting a sub-machine announces the active child's exit
## before the sub-machine's own.


const LOG_LIMIT := 32

## Node name of the state to enter on setup (and on sub-machine re-entry).
@export var initial_state: StringName = &""

var blackboard: Blackboard = null
var navigation: NavigationAdapter = null
## Shared RNG for the state family; seed it for deterministic tests.
var rng := RandomNumberGenerator.new()
var active_state: AIState = null
## Recent transitions, oldest first: {from, to, at} with seconds since this
## machine started ticking. Read by the debug view.
var transition_log: Array[Dictionary] = []

var _states: Array[AIState] = []
var _elapsed := 0.0


## Wire the context and enter the initial state. Call on the ROOT machine
## after the machine and its state children are in the tree (add_child
## before setup).
func setup(blackboard_ref: Blackboard, navigation_ref: NavigationAdapter) -> void:
	blackboard = blackboard_ref
	navigation = navigation_ref
	brain = _root_machine()
	_setup_states()
	if initial_state != &"":
		var first := get_state(initial_state)
		if first != null:
			_switch_to(first)


func tick(delta: float) -> void:
	_elapsed += delta
	if _is_root() and blackboard != null:
		blackboard.tick(delta)
	if active_state == null:
		return
	_evaluate_transitions()
	if active_state != null:
		active_state.tick(delta)


## Debug affordance: drop the machine into a named child state directly,
## bypassing the transition table (bridge and console entry point).
func force_state(state_name: String) -> bool:
	var next := get_state(StringName(state_name))
	if next == null:
		push_warning("HFSM.force_state: no child state named %s" % state_name)
		return false
	_switch_to(next)
	return true


## The movement intent of the deepest active state, for the controller's
## _physics_process copy into the character input.
func move_intent() -> Vector3:
	if active_state == null:
		return Vector3.ZERO
	if active_state is HFSM:
		return (active_state as HFSM).move_intent()
	return active_state.move_direction


func face_intent() -> Vector3:
	if active_state == null:
		return Vector3.FORWARD
	if active_state is HFSM:
		return (active_state as HFSM).face_intent()
	return active_state.face_direction


func get_state(state_name: StringName) -> AIState:
	for state in _states:
		if state.name == state_name:
			return state
	return null


func get_states_recursive() -> Array[AIState]:
	var out: Array[AIState] = []
	out.append_array(_states)
	for state in _states:
		if state is HFSM:
			out.append_array((state as HFSM).get_states_recursive())
	return out


func enter() -> void:
	super.enter()
	if initial_state != &"":
		var first := get_state(initial_state)
		if first != null:
			_switch_to(first)


func exit() -> void:
	if active_state != null:
		active_state.exit()
		active_state.exited.emit(active_state.name)
		active_state = null
	super.exit()


func _is_root() -> bool:
	return not (get_parent() is AIState)


func _root_machine() -> HFSM:
	var node: HFSM = self
	while node.get_parent() is HFSM:
		node = node.get_parent() as HFSM
	return node


func _setup_states() -> void:
	var root := _root_machine()
	_states.clear()
	for child in get_children():
		if child is AIState:
			_states.append(child)
	for state in _states:
		state.brain = root
		_validate_table(state)
		if state is HFSM:
			(state as HFSM)._setup_states()


func _validate_table(state: AIState) -> void:
	for row in state.transitions:
		if row.to_state == &"":
			push_error("HFSM: state %s has a transition row with no to_state" % state.name)
		elif get_state(row.to_state) == null:
			push_error("HFSM: state %s transitions to unknown state %s" % [state.name, row.to_state])
		if row.guard != &"" and not state.has_method(row.guard):
			push_error("HFSM: state %s guard %s does not exist" % [state.name, row.guard])


func _evaluate_transitions() -> void:
	if active_state == null:
		return
	for row in active_state.transitions:
		if _guard_passes(active_state, row):
			_switch_to(get_state(row.to_state))
			return


func _guard_passes(state: AIState, row: Transition) -> bool:
	if row.guard == &"":
		return true
	if not state.has_method(row.guard):
		return false
	var passed: bool = state.call(row.guard)
	return passed


func _switch_to(next: AIState) -> void:
	if next == null:
		return
	var from_name := &""
	if active_state != null:
		from_name = active_state.name
		active_state.exit()
		active_state.exited.emit(active_state.name)
	active_state = next
	next.enter()
	next.entered.emit(next.name)
	transition_log.append({"from": from_name, "to": next.name, "at": _elapsed})
	while transition_log.size() > LOG_LIMIT:
		transition_log.pop_front()
