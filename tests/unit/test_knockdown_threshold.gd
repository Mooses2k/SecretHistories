extends GutTest
# Owner ruling: a knockdown requires a single damage event above 50.
# Pins the boundary exactly: 50 must NOT knock down, 51 must.

const StateScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_state.gd")
const ParametersScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_parameters.gd")
const InputScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_input.gd")
const HurtboxScript = preload("res://scenes/hurtbox.gd")

var _root : Node


func _make_state() -> Node:
	_root = Node.new()
	# The root must be IN the tree before the children are added, so the
	# state's _ready/@onready wiring (Parameters, Input) actually runs.
	add_child_autofree(_root)
	var params : Node = ParametersScript.new()
	params.name = "Parameters"
	var input_node : Node = InputScript.new()
	input_node.name = "Input"
	var state : Node = StateScript.new()
	state.name = "State"
	_root.add_child(params)
	_root.add_child(input_node)
	_root.add_child(state)
	# Production binds a real Hurtbox into _on_damaged (_collect_hurtboxes),
	# so the KO branch's hurtbox.get_parent() needs a live node here too.
	var hurtbox : Node = HurtboxScript.new()
	hurtbox.name = "TestHurtbox"
	_root.add_child(hurtbox)
	state.owner = _root
	return state


func test_threshold_50_does_not_knock_down() -> void:
	var state := _make_state()
	assert_eq(state.parameters.ragdoll_damage_threshold, 50, "threshold constant must carry the owner ruling value")
	watch_signals(state)
	state._on_damaged(50, 0, Vector3.FORWARD, Vector3.ZERO, _root.get_node("TestHurtbox"))
	assert_eq(state.physical_state, state.PhysicalState.NORMAL, "50 damage must not knock down")
	assert_eq(state.durability, 50, "50 damage must still be deducted from durability")
	assert_signal_not_emitted(state, "physical_state_changed")


func test_threshold_51_knocks_down() -> void:
	var state := _make_state()
	watch_signals(state)
	state._on_damaged(51, 0, Vector3.FORWARD, Vector3.ZERO, _root.get_node("TestHurtbox"))
	assert_eq(state.physical_state, state.PhysicalState.KNOCKED_OUT, "51 damage must knock down")
	assert_eq(state.durability, 49, "51 damage must still be deducted from durability")
	assert_signal_emitted_with_parameters(state, "physical_state_changed", [1])
