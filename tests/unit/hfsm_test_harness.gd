extends RefCounted

## Bare-brain test harness for the HFSM suites: assembles a Blackboard + HFSM
## + chosen states as a plain node tree with a fake character, a scripted
## NavigationAdapter (goals and arrivals driven by the test), and fake weapon
## and inventory doubles. No timers and no physics: suites call
## machine.tick(0.1) directly. Seed machine.rng for determinism.


## Scripted stand-in for NavigationAdapter: goals are recorded, the arrival
## flag and movement intent are driven by the test. The real adapter's
## NavigationServer and WorldData queries stay untouched.
class FakeNavigation extends NavigationAdapter:
	var last_goal := Vector3.ZERO
	var goal_count := 0
	var arrived := false
	var intent := Vector3.ZERO

	func go_to(goal: Vector3) -> void:
		last_goal = goal
		goal_count += 1
		arrived = false

	func at_destination() -> bool:
		return arrived

	func move_intent() -> Vector3:
		return intent


## Minimal GunItem-shaped double: counts reloads and shots instead of doing
## ballistics. Exposes the same surface the BT gun nodes used; the ammo types
## are keyed like the real item, Resources, so tests share one key object.
class FakeGun extends RefCounted:
	var current_ammo := 0
	var ammo_types: Array = []
	var reload_calls := 0
	var shot_calls := 0
	var cylinder := 6

	func reload() -> void:
		reload_calls += 1
		current_ammo = cylinder

	func _use_primary() -> void:
		shot_calls += 1
		current_ammo -= 1


## Minimal Inventory-shaped double: tiny_items keyed like the real one.
class FakeInventory extends RefCounted:
	var tiny_items := {}


## Minimal MeleeItem-shaped double: counts cuts and thrusts.
class FakeMelee extends RefCounted:
	var cut_calls := 0
	var thrust_calls := 0

	func attack_cut() -> void:
		cut_calls += 1

	func attack_thrust() -> void:
		thrust_calls += 1


## Build the machine with named state children. Add it to the test (add_child
## before setup), then call setup(blackboard, navigation).
static func build_machine(states: Array[AIState], initial: String) -> HFSM:
	var machine := HFSM.new()
	machine.name = "Brain"
	machine.initial_state = StringName(initial)
	for state in states:
		machine.add_child(state)
	return machine


static func named(state: AIState, state_name: String) -> AIState:
	state.name = state_name
	return state


static func make_transition(to_state: String, guard: String) -> AIState.Transition:
	var row := AIState.Transition.new()
	row.to_state = StringName(to_state)
	row.guard = StringName(guard)
	return row


static func record(state: AIState, log: Array) -> void:
	state.entered.connect(func(name: StringName): log.append("enter:%s" % name))
	state.exited.connect(func(name: StringName): log.append("exit:%s" % name))


## A bare Player instance without the scene: enough for the `is Player`
## checks the threat model and the save surface do. Free it when done.
static func bare_player() -> Player:
	var script: GDScript = load("res://scenes/characters/player/player.gd")
	var player: Player = script.new() as Player
	return player
