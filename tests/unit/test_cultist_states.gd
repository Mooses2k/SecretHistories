extends GutTest

## The shared cultist states against synthetic stimuli, ticked directly: the
## 3.x parity cadences (idle wait 5 to 15 s, patrol pick 1 to 15 m, shot wait
## 0.75 to 1.55 s), suspicious face-and-hold, investigate-search-decay,
## combat entry on sight, the gun reload chain and melee fallback, and the
## terminal dead state.

const H := preload("res://tests/unit/hfsm_test_harness.gd")

var blackboard: Blackboard
var navigation: H.FakeNavigation
var machine: HFSM
var character: Node3D


func before_each() -> void:
	blackboard = Blackboard.new()
	navigation = H.FakeNavigation.new()
	character = Node3D.new()
	add_child(character)
	navigation.character = character


func after_each() -> void:
	if is_instance_valid(navigation):
		navigation.free()
	navigation = null
	if is_instance_valid(machine):
		machine.free()
	machine = null
	if is_instance_valid(character):
		character.free()
	character = null


func _setup_machine(states: Array[AIState], initial: String) -> HFSM:
	var built := H.build_machine(states, initial)
	add_child(built)
	built.setup(blackboard, navigation)
	machine = built
	return built


func test_idle_waits_the_3x_cadence_then_hands_to_patrol() -> void:
	var idle := H.named(AIStateIdle.new(), "Idle")
	var patrol := H.named(AIStatePatrol.new(), "Patrol")
	idle.transitions = [H.make_transition("Patrol", "guard_wait_elapsed")]
	_setup_machine([idle, patrol], "Idle")
	machine.rng.seed = 20250101
	machine.force_state("Idle")
	assert_true(idle.wait_time >= 5.0 and idle.wait_time <= 15.0,
		"the wait rolls inside the 3.x 5 to 15 s range, got %f" % idle.wait_time)
	var still_waiting := int(floor(idle.wait_time / 0.1)) - 1
	for i in still_waiting:
		machine.tick(0.1)
	assert_eq(machine.active_state, idle, "still idle before the wait elapses")
	for i in 200:
		if machine.active_state != idle:
			break
		machine.tick(0.1)
	assert_eq(machine.active_state, patrol, "the wait hands over through the table")


func test_patrol_picks_within_the_3x_radius_then_hands_to_idle() -> void:
	var patrol := H.named(AIStatePatrol.new(), "Patrol")
	var idle := H.named(AIStateIdle.new(), "Idle")
	patrol.transitions = [H.make_transition("Idle", "guard_arrived")]
	_setup_machine([patrol, idle], "Patrol")
	machine.rng.seed = 7
	machine.force_state("Patrol")
	var goal: Vector3 = navigation.last_goal
	var distance: float = character.global_position.distance_to(goal)
	assert_true(distance >= 1.0 and distance <= 15.0,
		"the goal lands inside the 1 to 15 m radius, got %f" % distance)
	navigation.arrived = true
	machine.tick(0.1)
	assert_eq(machine.active_state, idle, "arrival hands over through the table")


func test_patrol_walks_and_faces_its_movement() -> void:
	var patrol := H.named(AIStatePatrol.new(), "Patrol")
	_setup_machine([patrol], "Patrol")
	navigation.intent = Vector3(0.0, 0.0, 1.0)
	machine.tick(0.1)
	assert_almost_eq(patrol.move_direction, Vector3(0.0, 0.0, 1.0), Vector3(0.001, 0.001, 0.001))
	assert_almost_eq(patrol.face_direction, Vector3(0.0, 0.0, 1.0), Vector3(0.001, 0.001, 0.001))


func test_suspicious_faces_the_stimulus_then_holds() -> void:
	var suspicious := H.named(AIStateSuspicious.new(), "Suspicious")
	var idle := H.named(AIStateIdle.new(), "Idle")
	var investigate := H.named(AIStateInvestigate.new(), "Investigate")
	suspicious.transitions = [
		H.make_transition("Investigate", "guard_alert_at_least_investigate"),
		H.make_transition("Idle", "guard_hold_elapsed"),
	]
	_setup_machine([suspicious, idle, investigate], "Idle")
	blackboard.apply_stimulus(Blackboard.StimulusKind.SOUND, 10.0, Vector3(3.0, 0.0, 0.0))
	assert_true(machine.force_state("Suspicious"))
	assert_almost_eq(suspicious.face_direction, Vector3(1.0, 0.0, 0.0),
		Vector3(0.001, 0.001, 0.001), "faces the stimulus")
	for i in 19:
		machine.tick(0.1)
	assert_eq(machine.active_state, suspicious, "still holding before 2.0 s")
	for i in 2:
		machine.tick(0.1)
	assert_eq(machine.active_state, idle, "the hold hands back to idle")
	assert_null(blackboard.target, "a sub-bar sound never names a target")


func test_investigate_goes_to_the_stimulus_searches_then_hands_back() -> void:
	var investigate := H.named(AIStateInvestigate.new(), "Investigate")
	var patrol := H.named(AIStatePatrol.new(), "Patrol")
	investigate.transitions = [
		H.make_transition("Patrol", "guard_search_elapsed"),
		H.make_transition("Patrol", "guard_alert_below_investigate"),
	]
	_setup_machine([investigate, patrol], "Investigate")
	blackboard.apply_stimulus(Blackboard.StimulusKind.SOUND, 50.0, Vector3(5.0, 0.0, 0.0))
	assert_true(machine.force_state("Investigate"))
	assert_eq(navigation.last_goal, Vector3(5.0, 0.0, 0.0), "the goal is the stimulus position")
	navigation.intent = Vector3(0.0, 0.0, -1.0)
	machine.tick(0.1)
	assert_almost_eq(investigate.move_direction, Vector3(0.0, 0.0, -1.0),
		Vector3(0.001, 0.001, 0.001), "walking the stimulus down")
	navigation.arrived = true
	for i in 29:
		machine.tick(0.1)
	assert_eq(machine.active_state, investigate, "still searching before 3.0 s")
	machine.tick(0.1)
	machine.tick(0.1)
	assert_eq(machine.active_state, patrol, "the search hands back through the table")


func test_investigate_abandons_a_stale_stimulus_mid_goto() -> void:
	var investigate := H.named(AIStateInvestigate.new(), "Investigate")
	var patrol := H.named(AIStatePatrol.new(), "Patrol")
	investigate.transitions = [
		H.make_transition("Patrol", "guard_search_elapsed"),
		H.make_transition("Patrol", "guard_alert_below_investigate"),
	]
	_setup_machine([investigate, patrol], "Investigate")
	blackboard.apply_stimulus(Blackboard.StimulusKind.SOUND, 30.0, Vector3(5.0, 0.0, 0.0))
	assert_true(machine.force_state("Investigate"))
	navigation.arrived = false
	for i in 50:
		machine.tick(0.1)
	assert_eq(machine.active_state, investigate, "the attention span holds while walking")
	machine.tick(0.1)
	assert_eq(machine.active_state, patrol, "decayed below the bar mid-goto, the creature gives up")


func test_combat_entry_on_sight_enters_the_sub_machine() -> void:
	var idle := H.named(AIStateIdle.new(), "Idle")
	var combat := H.named(AIStateCombat.new(), "Combat")
	var approach := H.named(AIStateApproach.new(), "Approach")
	combat.add_child(approach)
	combat.initial_state = &"Approach"
	idle.transitions = [H.make_transition("Combat", "guard_can_fight")]
	var built := H.build_machine([idle, combat], "Idle")
	add_child(built)
	var log: Array = []
	H.record(idle, log)
	H.record(combat, log)
	H.record(approach, log)
	built.setup(blackboard, navigation)
	machine = built
	var player := H.bare_player()
	blackboard.apply_stimulus(Blackboard.StimulusKind.SIGHT, 300.0, Vector3(1.0, 0.0, 0.0), player)
	machine.tick(0.1)
	assert_eq(machine.active_state, combat, "combat-level sight opens combat")
	var nested: HFSM = machine.active_state as HFSM
	assert_eq(nested.active_state, approach, "and the sub-machine starts by approaching")
	assert_eq(log, ["enter:Idle", "exit:Idle", "enter:Approach", "enter:Combat"],
		"entry is announced for the sub-machine and its child (innermost first)")
	player.free()


func test_combat_leaves_when_the_target_is_gone() -> void:
	var combat := H.named(AIStateCombat.new(), "Combat")
	var approach := H.named(AIStateApproach.new(), "Approach")
	combat.add_child(approach)
	combat.initial_state = &"Approach"
	combat.transitions = [H.make_transition("Investigate", "guard_no_target")]
	var investigate := H.named(AIStateInvestigate.new(), "Investigate")
	_setup_machine([combat, investigate], "Combat")
	var player := H.bare_player()
	blackboard.target = player
	assert_true(machine.force_state("Combat"))
	blackboard.target = null
	machine.tick(0.1)
	assert_eq(machine.active_state, investigate, "losing the target leaves combat through the table")
	player.free()


func test_gun_attack_reloads_a_dry_gun_then_fires_on_cadence() -> void:
	var gun := H.FakeGun.new()
	var ammo: Resource = Resource.new()
	gun.ammo_types = [ammo]
	var inventory := H.FakeInventory.new()
	inventory.tiny_items[ammo] = 4
	var gun_attack := H.named(AIStateGunAttack.new(), "GunAttack")
	gun_attack.weapon = gun
	gun_attack.ammo_source = inventory
	var player := H.bare_player()
	blackboard.target = player
	_setup_machine([gun_attack], "GunAttack")
	machine.rng.seed = 11
	var events: Array = []
	gun_attack.anim_event.connect(func(name: StringName): events.append(name))
	machine.tick(0.1)
	assert_eq(gun.reload_calls, 1, "a dry gun with reserve ammo reloads")
	assert_eq(int(gun.current_ammo), 6, "the reload fills the cylinder")
	assert_true(events.has(&"reload"), "the reload emits the anim event for the bridge")
	var shot_ticks: Array[int] = []
	for i in 200:
		machine.tick(0.1)
		if gun.shot_calls > shot_ticks.size():
			shot_ticks.append(i)
	assert_true(gun.shot_calls >= 5, "the cadence keeps firing, got %d shots" % gun.shot_calls)
	for i in range(1, shot_ticks.size()):
		var gap: float = float(shot_ticks[i] - shot_ticks[i - 1]) * 0.1
		assert_true(gap >= 0.65 and gap <= 1.7,
			"shot gaps stay inside the 0.75 to 1.55 s band plus tick slop, got %f" % gap)
	player.free()


func test_a_dry_gun_without_reserve_falls_back_to_melee() -> void:
	var gun := H.FakeGun.new()
	var inventory := H.FakeInventory.new()
	var gun_attack := H.named(AIStateGunAttack.new(), "GunAttack")
	gun_attack.weapon = gun
	gun_attack.ammo_source = inventory
	gun_attack.transitions = [H.make_transition("MeleeAttack", "guard_gun_unusable")]
	var melee := H.named(AIStateMeleeAttack.new(), "MeleeAttack")
	_setup_machine([gun_attack, melee], "GunAttack")
	machine.tick(0.1)
	assert_eq(machine.active_state, melee, "dry and empty reserve hands off to the melee attack")
	assert_eq(gun.reload_calls, 0, "nothing to reload with")


func test_melee_chops_on_cooldown_and_thrusts_when_selected() -> void:
	var melee_item := H.FakeMelee.new()
	var melee := H.named(AIStateMeleeAttack.new(), "MeleeAttack")
	melee.weapon = melee_item
	_setup_machine([melee], "MeleeAttack")
	machine.rng.seed = 3
	machine.tick(0.1)
	assert_eq(melee_item.cut_calls, 1, "the first chop is immediate")
	assert_eq(melee_item.thrust_calls, 0, "the default thrust_ratio chops only")
	machine.tick(0.1)
	assert_eq(melee_item.cut_calls, 1, "the cooldown gates the next chop")
	for i in 20:
		machine.tick(0.1)
	assert_true(melee_item.cut_calls >= 2, "the chop repeats on its cooldown")
	var cuts_before := melee_item.cut_calls
	melee.thrust_ratio = 1.0
	melee.cooldown = 0.0
	machine.tick(0.1)
	assert_eq(melee_item.thrust_calls, 1, "ratio 1.0 picks the exposed thrust attack")
	assert_eq(melee_item.cut_calls, cuts_before)


func test_dead_is_terminal() -> void:
	var idle := H.named(AIStateIdle.new(), "Idle")
	var dead_state := H.named(AIStateDead.new(), "Dead")
	idle.transitions = [H.make_transition("Dead", "guard_is_dead")]
	_setup_machine([idle, dead_state], "Idle")
	var died_count: Array[int] = [0]
	dead_state.died.connect(func(): died_count[0] += 1)
	blackboard.dead = true
	machine.tick(0.1)
	assert_eq(machine.active_state, dead_state, "the death guard enters Dead")
	assert_eq(died_count[0], 1, "the death is announced once")
	assert_eq(dead_state.move_direction, Vector3.ZERO, "intents are cleared")
	var log_size: int = machine.transition_log.size()
	for i in 5:
		machine.tick(0.1)
	assert_eq(machine.active_state, dead_state, "Dead parks the machine for good")
	assert_eq(machine.transition_log.size(), log_size, "no further transitions")


func test_flee_runs_directly_away_from_the_threat() -> void:
	var flee := H.named(AIStateFlee.new(), "Flee")
	_setup_machine([flee], "Flee")
	var player := H.bare_player()
	player.position = Vector3(2.0, 0.0, 0.0)
	blackboard.target = player
	assert_true(machine.force_state("Flee"))
	assert_almost_eq(navigation.last_goal, Vector3(-10.0, 0.0, 0.0), Vector3(0.01, 0.01, 0.01),
		"the escape goal is flee_distance away, opposite the threat")
	navigation.intent = Vector3(-1.0, 0.0, 0.0)
	machine.tick(0.1)
	assert_almost_eq(flee.move_direction, Vector3(-1.0, 0.0, 0.0), Vector3(0.001, 0.001, 0.001))
	player.free()
