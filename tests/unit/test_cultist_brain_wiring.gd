extends GutTest

## The live neophyte brain against synthetic stimuli: the real scene
## instantiates, its controller boots the HFSM, and direct deterministic
## ticks drive sight-of-player combat, gunshot investigation, alertness
## decay back to the wander set, the death guard, and the declared
## transition tables. The TickTimer is stopped; the test ticks directly.

const NEOPHYTE_SCENE := "res://scenes/characters/cultist/neophyte.tscn"
const AI_CONTROLLER_SCRIPT := "res://scenes/characters/cultist/ai_controller.gd"
const H := preload("res://tests/unit/hfsm_test_harness.gd")

var _cultist: Node
var _controller: Node
var _board: Blackboard


func after_each() -> void:
	if _board != null and _board.target is Player:
		(_board.target as Player).free()
	if is_instance_valid(_cultist):
		_cultist.free()
	_cultist = null
	_controller = null
	_board = null


func _boot_cultist() -> void:
	_cultist = (load(NEOPHYTE_SCENE) as PackedScene).instantiate()
	add_child(_cultist)
	var controller_script: GDScript = load(AI_CONTROLLER_SCRIPT)
	for child in _cultist.get_children():
		if child.get_script() == controller_script:
			_controller = child
	assert_not_null(_controller, "the AIController is found by script path")
	(_controller.get_node("TickTimer") as Timer).stop()
	_board = _controller.ai_state
	assert_not_null(_board, "the controller carries the blackboard as ai_state")


func _brain() -> HFSM:
	return _controller.brain


func _tick(times: int) -> void:
	for i in times:
		_controller.tick()


func test_the_neophyte_brain_boots_and_ticks_without_errors() -> void:
	_boot_cultist()
	var brain := _brain()
	assert_not_null(brain, "the Brain HFSM is wired under the AIController")
	assert_eq(brain.blackboard, _board, "the machine runs on the controller's blackboard")
	assert_eq(brain.navigation, _controller.navigation_adapter, "the navigation adapter is wired")
	var adapter: StimulusAdapter = _controller.stimulus_adapter
	assert_eq(adapter.blackboard, _board, "the stimulus adapter feeds the same blackboard")
	assert_not_null(brain.active_state, "setup entered the initial state")
	_tick(10)
	var active_name := String(brain.active_state.name)
	assert_true(active_name == "Idle" or active_name == "Patrol",
		"the idle loop boots, got %s" % active_name)


func test_sees_player_opens_combat_through_the_sub_machine() -> void:
	_boot_cultist()
	_controller.tick()
	var player := H.bare_player()
	player.position = Vector3(2.0, 0.0, 0.0)
	_controller.stimulus_adapter.simulate_stimulus(
		Blackboard.StimulusKind.SIGHT, Vector3(2.0, 0.0, 0.0), 300.0, player)
	_controller.tick()
	var brain := _brain()
	assert_eq(brain.active_state, _controller.combat, "sight of the player opens combat")
	assert_eq(_controller.combat.active_state, _controller.approach,
		"the sub-machine starts by approaching")
	_board.target = null
	player.free()


func test_gunshot_stimulus_drives_investigate() -> void:
	_boot_cultist()
	_controller.tick()
	_controller.stimulus_adapter.simulate_stimulus(
		Blackboard.StimulusKind.SOUND, Vector3(5.0, 0.0, 0.0), 50.0)
	_controller.tick()
	var brain := _brain()
	assert_eq(brain.active_state, brain.get_state(&"Investigate"),
		"a loud noise sends the cultist to investigate")
	assert_eq(_board.last_stimulus.kind, Blackboard.StimulusKind.SOUND,
		"the stimulus that opened the investigation was the sound")


func test_lost_target_decays_back_to_the_wander_set() -> void:
	_boot_cultist()
	_controller.tick()
	var player := H.bare_player()
	player.position = Vector3(2.0, 0.0, 0.0)
	_controller.stimulus_adapter.simulate_stimulus(
		Blackboard.StimulusKind.SIGHT, Vector3(2.0, 0.0, 0.0), 300.0, player)
	_controller.tick()
	assert_eq(_brain().active_state, _controller.combat, "combat is open")
	# Six seconds of silence: the sight conclusion lapses past the attention
	# span, alertness decays, investigate gives up, and the wander set
	# resumes. No new stimuli, deterministic ticks only.
	_tick(200)
	var active_name := String(_brain().active_state.name)
	assert_true(active_name == "Idle" or active_name == "Patrol",
		"the lost target decays back to the wander set, got %s" % active_name)
	assert_null(_board.target, "the stale target reference is cleared")
	_board.target = null
	player.free()


func test_the_death_guard_parks_the_machine_on_dead() -> void:
	_boot_cultist()
	_controller.tick()
	var died_count: Array[int] = [0]
	(_brain().get_state(&"Dead") as AIStateDead).died.connect(
		func(): died_count[0] += 1)
	_board.dead = true
	_controller.tick()
	assert_eq(_brain().active_state, _brain().get_state(&"Dead"), "the death guard enters Dead")
	assert_eq(died_count[0], 1, "the death is announced once")
	_tick(5)
	assert_eq(_brain().active_state, _brain().get_state(&"Dead"), "Dead parks the machine")


func test_the_declared_transition_tables_resolve() -> void:
	_boot_cultist()
	var brain := _brain()
	var machines: Array[HFSM] = [brain, _controller.combat]
	for machine in machines:
		for state in machine.get_children():
			if not (state is AIState):
				continue
			var state_state := state as AIState
			if state_state is AIStateDead:
				assert_eq(state_state.transitions.size(), 0,
					"Dead is terminal and declares no outgoing rows")
				continue
			assert_true(state_state.transitions.size() > 0,
				"state %s declares a table" % state_state.name)
			for row in state_state.transitions:
				assert_not_null(machine.get_state(row.to_state),
					"row %s -> %s resolves on %s" % [state_state.name, row.to_state, machine.name])
				if row.guard != &"":
					assert_true(state_state.has_method(row.guard),
						"guard %s exists on %s" % [row.guard, state_state.name])
	# Every root state's first row is the death guard.
	for state in brain.get_children():
		if not (state is AIState) or state is HFSM:
			continue
		var state_state := state as AIState
		if state_state.name != &"Dead":
			assert_eq(state_state.transitions[0].guard, &"guard_is_dead",
				"the death guard is the first row on %s" % state_state.name)


func test_the_debug_surface_is_wired() -> void:
	_boot_cultist()
	var label := _brain().get_node_or_null("StateLabel") as Label3D
	assert_not_null(label, "the state label rides under the Brain")
	assert_false(label.visible, "the state label is off by default")
	var target_viz := _cultist.get_node("DebugVisualizers/TargetPosition") as MeshInstance3D
	var path_viz := _cultist.get_node("DebugVisualizers/Path") as MeshInstance3D
	var target_script: GDScript = load("res://core/ai/debug/debugviz_target_position.gd")
	var path_script: GDScript = load("res://core/ai/debug/debugviz_path.gd")
	assert_eq(target_viz.get_script(), target_script, "the target visualizer reads the HFSM adapter")
	assert_eq(path_viz.get_script(), path_script, "the path visualizer reads the HFSM adapter")
