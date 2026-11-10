extends GutTest

## Transition-table semantics of the HFSM runner: priority order, exit-then-
## enter ordering, re-entry, the one-active-state invariant, guards evaluated
## every tick even mid-goto (the structural fix for the BT's ignored
## stimuli, issue #450), sub-machine nesting, and force_state.

const H := preload("res://tests/unit/hfsm_test_harness.gd")

## Controllable test state: counts ticks, exposes a guard that passes after
## `open_after` ticks.
class TimedState extends AIState:
	var open_after := 3
	var ticks := 0
	var enter_count := 0
	var exit_count := 0

	func enter() -> void:
		super.enter()
		enter_count += 1

	func exit() -> void:
		super.exit()
		exit_count += 1

	func tick(_delta: float) -> void:
		ticks += 1

	func guard_time_up() -> bool:
		return ticks >= open_after


var blackboard: Blackboard
var navigation: H.FakeNavigation
var machine: HFSM


func before_each() -> void:
	blackboard = Blackboard.new()
	navigation = H.FakeNavigation.new()


func after_each() -> void:
	if is_instance_valid(navigation):
		navigation.free()
	navigation = null
	if is_instance_valid(machine):
		machine.free()
	machine = null


func _build_machine(states: Array[AIState], initial: String) -> HFSM:
	var built := H.build_machine(states, initial)
	add_child(built)
	machine = built
	return built


func test_setup_enters_the_initial_state() -> void:
	var a := H.named(TimedState.new(), "A")
	var log: Array = []
	H.record(a, log)
	var built := _build_machine([a], "A")
	built.setup(blackboard, navigation)
	assert_eq(machine.active_state, a, "the machine parks on the initial state")
	assert_true(log.has("enter:A"), "the initial entry is announced")


func test_first_passing_row_in_declared_order_wins() -> void:
	var a := H.named(TimedState.new(), "A")
	a.open_after = 0
	var b := H.named(TimedState.new(), "B")
	var c := H.named(TimedState.new(), "C")
	a.transitions = [
		H.make_transition("B", "guard_time_up"),
		H.make_transition("C", "guard_always"),
	]
	var built := _build_machine([a, b, c], "A")
	built.setup(blackboard, navigation)
	machine.tick(0.1)
	assert_eq(machine.active_state, b, "the earlier declared row wins when both guards pass")


func test_exit_fires_before_enter() -> void:
	var a := H.named(TimedState.new(), "A")
	a.open_after = 0
	a.transitions = [H.make_transition("B", "guard_time_up")]
	var b := H.named(TimedState.new(), "B")
	var built := _build_machine([a, b], "A")
	var log: Array = []
	H.record(a, log)
	H.record(b, log)
	built.setup(blackboard, navigation)
	machine.tick(0.1)
	assert_eq(log.size(), 3, "exit then enter, nothing else")
	assert_eq(log[0], "enter:A")
	assert_eq(log[1], "exit:A", "the old state exits first")
	assert_eq(log[2], "enter:B", "the new state enters second")


func test_reentry_runs_enter_again() -> void:
	var a := H.named(TimedState.new(), "A")
	a.open_after = 0
	var b := H.named(TimedState.new(), "B")
	a.transitions = [H.make_transition("B", "guard_time_up")]
	b.transitions = [H.make_transition("A", "guard_always")]
	var built := _build_machine([a, b], "A")
	built.setup(blackboard, navigation)
	machine.tick(0.1)
	assert_eq(machine.active_state, b)
	machine.tick(0.1)
	assert_eq(machine.active_state, a)
	assert_eq(a.enter_count, 2, "re-entry runs enter again, not a resumed tick")


func test_exactly_one_active_state_holds_across_toggles() -> void:
	var a := H.named(TimedState.new(), "A")
	a.open_after = 1
	var b := H.named(TimedState.new(), "B")
	b.open_after = 2
	a.transitions = [H.make_transition("B", "guard_time_up")]
	b.transitions = [H.make_transition("A", "guard_time_up")]
	var built := _build_machine([a, b], "A")
	built.setup(blackboard, navigation)
	for i in 20:
		machine.tick(0.1)
	for state: TimedState in [a, b]:
		if state == machine.active_state:
			assert_eq(state.enter_count, state.exit_count + 1,
				"%s holds exactly one activation" % state.name)
		else:
			assert_eq(state.enter_count, state.exit_count,
				"%s is fully exited" % state.name)


func test_guards_are_evaluated_every_tick_mid_goto() -> void:
	# Issue #450: the BT only ran checks where its sequence placed them, so a
	# stimulus that arrived during a goto was ignored until the action ended.
	# The runner re-evaluates the active state's table on every tick.
	var investigate := H.named(AIStateInvestigate.new(), "Investigate")
	var combat := H.named(AIStateCombat.new(), "Combat")
	combat.initial_state = &"Approach"
	combat.add_child(H.named(AIStateApproach.new(), "Approach"))
	investigate.transitions = [H.make_transition("Combat", "guard_can_fight")]
	var built := _build_machine([investigate, combat], "Investigate")
	built.setup(blackboard, navigation)
	navigation.arrived = false
	navigation.intent = Vector3(0.0, 0.0, -1.0)
	var player := H.bare_player()
	for i in 3:
		machine.tick(0.1)
	assert_eq(machine.active_state, investigate, "nothing new, the goto continues")
	blackboard.apply_stimulus(Blackboard.StimulusKind.SIGHT, 300.0, Vector3.ZERO, player)
	machine.tick(0.1)
	assert_eq(machine.active_state, combat, "the sight stimulus interrupts the goto on the next tick")
	var nested: HFSM = machine.active_state as HFSM
	assert_eq(nested.active_state.name, &"Approach", "the sub-machine entered its own initial state")
	player.free()


func test_submachine_enter_and_exit_wrap_around_the_child() -> void:
	var idle := H.named(TimedState.new(), "Idle")
	var combat := H.named(AIStateCombat.new(), "Combat")
	var approach := H.named(AIStateApproach.new(), "Approach")
	combat.add_child(approach)
	combat.initial_state = &"Approach"
	var built := _build_machine([idle, combat], "Idle")
	var log: Array = []
	H.record(idle, log)
	H.record(combat, log)
	H.record(approach, log)
	built.setup(blackboard, navigation)
	assert_true(machine.force_state("Combat"), "force_state finds the sub-machine")
	assert_eq(log, ["enter:Idle", "exit:Idle", "enter:Approach", "enter:Combat"],
		"entering a sub-machine announces it, then its initial child (innermost first)")
	assert_true(machine.force_state("Idle"))
	assert_eq(log[4], "exit:Approach", "the active child exits before the sub-machine")
	assert_eq(log[5], "exit:Combat")
	assert_eq(log[6], "enter:Idle")


func test_submachine_internal_handoff_by_guard() -> void:
	var character := Node3D.new()
	add_child(character)
	navigation.character = character
	var target := Node3D.new()
	add_child(target)
	target.position = Vector3(0.2, 0.0, 0.0)
	blackboard.target = target
	blackboard.alertness = blackboard.combat_bar
	var combat := H.named(AIStateCombat.new(), "Combat")
	var approach := H.named(AIStateApproach.new(), "Approach")
	var gun_attack := H.named(AIStateGunAttack.new(), "GunAttack")
	approach.transitions = [H.make_transition("GunAttack", "guard_in_shoot_range")]
	combat.add_child(approach)
	combat.add_child(gun_attack)
	combat.initial_state = &"Approach"
	var built := _build_machine([combat], "Combat")
	built.setup(blackboard, navigation)
	var nested: HFSM = machine.active_state as HFSM
	assert_eq(nested.active_state, approach, "combat starts by approaching")
	machine.tick(0.1)
	assert_eq(nested.active_state, gun_attack, "in-range target hands off to the gun attack")
	character.free()
	target.free()


func test_force_state_bypasses_the_table_and_is_logged() -> void:
	var idle := H.named(TimedState.new(), "Idle")
	var patrol := H.named(TimedState.new(), "Patrol")
	var built := _build_machine([idle, patrol], "Idle")
	built.setup(blackboard, navigation)
	assert_true(machine.force_state("Patrol"))
	assert_eq(machine.active_state, patrol)
	var last: Dictionary = machine.transition_log.back()
	assert_eq(last["from"], "Idle")
	assert_eq(last["to"], "Patrol")
	assert_false(machine.force_state("Nope"), "an unknown state name is refused")
	assert_eq(machine.active_state, patrol, "and leaves the machine where it was")


func test_transition_log_stays_bounded() -> void:
	var a := H.named(TimedState.new(), "A")
	var b := H.named(TimedState.new(), "B")
	a.transitions = [H.make_transition("B", "guard_always")]
	b.transitions = [H.make_transition("A", "guard_always")]
	var built := _build_machine([a, b], "A")
	built.setup(blackboard, navigation)
	for i in 40:
		machine.tick(0.1)
	assert_true(machine.transition_log.size() <= HFSM.LOG_LIMIT,
		"the log keeps its last %d entries, got %d" % [HFSM.LOG_LIMIT, machine.transition_log.size()])
