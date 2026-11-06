extends GutTest
# Owner ruling option c (stage-boundary interrupt): a slot switch during a
# reload must let the CURRENT stage finish (its rounds load, count preserved),
# abort any remaining stages, and leave a re-initiated reload to load only the
# remaining rounds. The unload (hold R) path keeps the inventory hard lock.
#
# Harness: real webley scene (its timers/sounds come from _gun_item.tscn) with
# a stub owner carrying a real HumanoidCharacterState and a real Inventory,
# the same pattern as test_bomb_cleanup.

const InventoryScript = preload("res://scenes/characters/inventory.gd")
const WebleyScene = preload("res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn")
const AmmoResource = preload("res://resources/tiny_items/ammunition/455_webley.tres")
const StateScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_state.gd")
const ParametersScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_parameters.gd")
const InputScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_input.gd")


class ReloadOwnerStub extends Node:
	var state = null
	var inventory = null


func _make_harness(start_ammo : int, start_tiny : int) -> Dictionary:
	var owner_stub : ReloadOwnerStub = ReloadOwnerStub.new()
	add_child_autofree(owner_stub)
	var params : Node = ParametersScript.new()
	params.name = "Parameters"
	var input_node : Node = InputScript.new()
	input_node.name = "Input"
	var state : Node = StateScript.new()
	state.name = "State"
	owner_stub.add_child(params)
	owner_stub.add_child(input_node)
	owner_stub.add_child(state)
	state.owner = owner_stub
	owner_stub.state = state

	var inv = add_child_autofree(InventoryScript.new())
	owner_stub.inventory = inv

	var webley = WebleyScene.instantiate()
	add_child_autofree(webley)
	webley.owner_character = owner_stub
	webley.ammunition_capacity = 6
	webley.reload_amount = 2
	webley.reload_time = 0.25
	webley.current_ammo_type = AmmoResource
	webley.current_ammo = start_ammo
	inv.tiny_items[AmmoResource] = start_tiny
	return {"owner": owner_stub, "state": state, "inventory": inv, "webley": webley}


func test_stage_boundary_abort_completes_the_in_flight_stage() -> void:
	var h := _make_harness(2, 10)
	var webley : Node = h.webley
	var state : Node = h.state
	watch_signals(webley)

	webley.reload()
	assert_true(state.is_reloading, "reload() must start a stage")
	assert_eq(state.reloading_item, webley, "reload() must register the reloading item on the state")

	# The slot switch request arrives while the stage is in flight.
	webley.request_reload_abort()

	await wait_for_signal(webley.reload_stage_finished, 2.0)
	# The current stage finished anyway: its rounds loaded, count preserved.
	assert_eq(webley.current_ammo, 4, "the in-flight stage must still load its rounds")
	assert_eq(h.inventory.tiny_items[AmmoResource], 8, "tiny ammo must be consumed exactly once for the finished stage")
	assert_false(state.is_reloading, "the stage boundary must clear is_reloading")
	assert_null(state.reloading_item, "the stage boundary must clear reloading_item")
	assert_signal_emitted_with_parameters(webley, "reload_stage_finished", [4])


func test_resume_after_abort_loads_only_the_remaining_rounds() -> void:
	var h := _make_harness(2, 10)
	var webley : Node = h.webley
	var state : Node = h.state

	webley.reload()
	webley.request_reload_abort()
	await wait_for_signal(webley.reload_stage_finished, 2.0)
	assert_eq(webley.current_ammo, 4, "stage 1 of the interrupted reload must stand")

	# Re-initiating later loads only what is missing, in stage-sized steps.
	webley.reload()
	await wait_for_signal(webley.reload_stage_finished, 2.0)
	assert_eq(webley.current_ammo, 6, "stage 2 must top the weapon up to capacity")
	assert_eq(h.inventory.tiny_items[AmmoResource], 6, "two stages of two rounds each must be consumed")

	# A full weapon refuses further reloads.
	webley.reload()
	assert_false(state.is_reloading, "a full weapon must not enter a reload stage")
	assert_eq(webley.current_ammo, 6, "a full weapon must not gain rounds")


func test_no_interrupt_reload_baseline_unchanged() -> void:
	var h := _make_harness(0, 6)
	var webley : Node = h.webley
	var state : Node = h.state
	watch_signals(webley)

	webley.reload()
	await wait_for_signal(webley.reload_stage_finished, 2.0)
	assert_eq(webley.current_ammo, 2, "an uninterrupted stage loads reload_amount rounds")
	assert_false(state.is_reloading, "an uninterrupted stage clears is_reloading")
	assert_null(state.reloading_item, "an uninterrupted stage clears reloading_item")
	assert_eq(h.inventory.tiny_items[AmmoResource], 4, "tiny ammo must be consumed by the loaded amount")


func test_unload_keeps_the_inventory_lock_semantics() -> void:
	var h := _make_harness(6, 0)
	var webley : Node = h.webley
	var state : Node = h.state

	webley.unload()
	assert_true(state.is_reloading, "unload() must hold the character reload flag")
	assert_null(state.reloading_item, "unload() must NOT register a reloading_item: switching stays locked")

	# The unload boundary is the UnloadTimer timeout; it does not emit the
	# reload stage signal, so wait out the 0.25 s unload time instead.
	await wait_seconds(0.6)
	assert_eq(webley.current_ammo, 0, "the unload must empty the weapon at its boundary")
	assert_eq(h.inventory.tiny_items[AmmoResource], 6, "the unload must return the rounds to the inventory")
	assert_false(state.is_reloading, "the unload boundary must clear is_reloading")
