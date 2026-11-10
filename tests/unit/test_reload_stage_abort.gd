extends GutTest
## Reload interruption: a mainhand slot switch during a gun reload requests
## an abort on the gun (gun_item.request_reload_abort), which preempts the
## in-flight staged reload at once. A staged reload lands one round per
## ReloadTimer cycle, each debited as it lands (owner ruling: one press loads
## the webley cylinder one round at a time up to 6), so the abort stops the
## remaining rounds: the rounds already inserted stand, the rest stay in the
## inventory, and the character reload state clears so a parked slot switch
## can run. The unload (hold R) path keeps the inventory hard lock.
##
## Harness: real webley scene (its timers/sounds come from _gun_item.tscn)
## with a stub owner carrying a real HumanoidCharacterState and a real
## Inventory, the same pattern as test_bomb_cleanup.

const InventoryScript = preload("res://scenes/characters/inventory.gd")
const WebleyScene = preload("res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn")
const AmmoResource = preload("res://resources/tiny_items/ammunition/455_webley.tres")
const StateScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_state.gd")
const ParametersScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_parameters.gd")
const InputScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_input.gd")


class ReloadOwnerStub extends Node:
	var state = null
	var inventory = null


func _make_harness(start_ammo : int, start_tiny : int, stage_amount : int = 2) -> Dictionary:
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
	webley.reload_amount = stage_amount
	webley.reload_time = 0.25
	webley.current_ammo_type = AmmoResource
	webley.current_ammo = start_ammo
	inv.tiny_items[AmmoResource] = start_tiny
	return {"owner": owner_stub, "state": state, "inventory": inv, "webley": webley}


func test_abort_preempts_the_in_flight_stage() -> void:
	var h := _make_harness(2, 10)
	var webley : Node = h.webley
	var state : Node = h.state
	watch_signals(webley)

	webley.reload()
	assert_true(state.is_reloading, "reload() must start a stage")
	assert_eq(state.reloading_item, webley, "reload() must register the reloading item on the state")

	# The slot switch request arrives while the stage is in flight.
	webley.request_reload_abort()

	assert_false(state.is_reloading, "the abort must clear is_reloading at once")
	assert_null(state.reloading_item, "the abort must clear reloading_item at once")
	assert_eq(webley.current_ammo, 2, "the rounds loaded before the stage must stand")
	assert_eq(h.inventory.tiny_items[AmmoResource], 10, "the queued rounds must not be consumed")

	# The preempted timer must stay dead: no late load, no late boundary.
	await wait_seconds(0.5)
	assert_eq(webley.current_ammo, 2, "the preempted stage must not load rounds later")
	assert_eq(h.inventory.tiny_items[AmmoResource], 10, "the preempted stage must not consume ammo later")
	assert_false(state.is_reloading, "the preempted stage must not restore the reload state")
	assert_signal_not_emitted(webley, "reload_stage_finished")


func test_abort_with_no_stage_in_flight_is_a_no_op() -> void:
	var h := _make_harness(2, 10)
	var webley : Node = h.webley
	var state : Node = h.state
	watch_signals(webley)

	webley.request_reload_abort()
	assert_false(state.is_reloading, "an abort with no reload must not touch the state")
	assert_null(state.reloading_item, "an abort with no reload must not register anything")
	assert_signal_not_emitted(webley, "reload_stage_finished")


func test_reload_after_abort_loads_only_the_remaining_rounds() -> void:
	var h := _make_harness(2, 10)
	var webley : Node = h.webley
	var state : Node = h.state

	webley.reload()
	webley.request_reload_abort()
	assert_eq(webley.current_ammo, 2, "the aborted stage must leave the loaded rounds standing")

	# Re-initiating later loads stage-sized steps from the standing count.
	webley.reload()
	await wait_for_signal(webley.reload_stage_finished, 2.0)
	assert_eq(webley.current_ammo, 4, "the follow-up stage loads the next stage amount")
	assert_eq(h.inventory.tiny_items[AmmoResource], 8, "the follow-up stage consumes exactly its rounds")

	webley.reload()
	await wait_for_signal(webley.reload_stage_finished, 2.0)
	assert_eq(webley.current_ammo, 6, "the last stage tops the weapon up to capacity")
	assert_eq(h.inventory.tiny_items[AmmoResource], 6, "the follow-up stages consume exactly their rounds")

	# A full weapon refuses further reloads.
	webley.reload()
	assert_false(state.is_reloading, "a full weapon must not enter a reload stage")
	assert_eq(webley.current_ammo, 6, "a full weapon must not gain rounds")


func test_webley_single_stage_reload_aborts_before_any_round_lands() -> void:
	# A full-cylinder-sized stage config (stage_amount 6 == capacity): the
	# interrupt must preempt that stage, otherwise the whole reload runs to
	# completion. Generic stage-amount pin; the shipped webley loads one round
	# per gate (next test).
	var h := _make_harness(0, 6, 6)
	var webley : Node = h.webley
	var state : Node = h.state
	watch_signals(webley)

	webley.reload()
	assert_true(state.is_reloading, "the single-stage reload must start")
	await wait_seconds(0.1)
	webley.request_reload_abort()

	assert_false(state.is_reloading, "the single-stage abort must clear is_reloading at once")
	assert_null(state.reloading_item, "the single-stage abort must clear reloading_item")
	assert_eq(webley.current_ammo, 0, "no queued round may land after the abort")
	assert_eq(h.inventory.tiny_items[AmmoResource], 6, "the full cylinder's worth of ammo must stay in the inventory")

	# A fresh reload without an interrupt loads the whole cylinder.
	webley.reload()
	await wait_for_signal(webley.reload_stage_finished, 2.0)
	assert_eq(webley.current_ammo, 6, "an uninterrupted single-stage reload fills the weapon")
	# The inventory erases a tiny item key at zero, so read via the accessor.
	assert_eq(h.inventory.tiny_item_amount(AmmoResource), 0, "the uninterrupted reload consumes all 6 rounds")


func test_shipped_webley_one_press_loads_the_cylinder_one_round_at_a_time() -> void:
	# Owner ruling, verbatim: "The webley used to reload correctly 1 at a time
	# up to 6 with ONE press." One press stages the whole cylinder; the rounds
	# land ONE per reload_time cycle, each with its per-chamber sound, until
	# the cylinder is full. Pins the staged chain: after the first cycle
	# exactly one round has landed (no jump to 6), and the press alone
	# finishes the full reload.
	var h := _make_harness(0, 6, 6)
	var webley : Node = h.webley
	var state : Node = h.state
	watch_signals(webley)
	assert_eq(webley.reload_amount, 6, "the shipped webley stages the full cylinder")

	webley.reload()
	assert_true(state.is_reloading, "the press starts the staged reload")
	await wait_seconds(0.35)
	assert_eq(webley.current_ammo, 1, "the first cycle lands exactly one round (no jump to 6)")
	assert_eq(h.inventory.tiny_item_amount(AmmoResource), 5, "exactly one round is debited per cycle")
	assert_true(state.is_reloading, "the staged reload continues without further presses")

	await wait_seconds(0.3)
	assert_eq(webley.current_ammo, 2, "the second cycle lands the next round on its own")

	await wait_for_signal(webley.reload_stage_finished, 3.0)
	assert_eq(webley.current_ammo, 6, "the one press finishes the full cylinder")
	assert_eq(h.inventory.tiny_item_amount(AmmoResource), 0, "all six rounds were consumed by the one press")
	assert_false(state.is_reloading, "the staged reload clears when the cylinder is full")

	# A full weapon refuses further reloads.
	webley.reload()
	assert_false(state.is_reloading, "a full weapon must not enter a reload stage")


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
	assert_signal_emitted_with_parameters(webley, "reload_stage_finished", [2])


func test_unload_keeps_the_inventory_lock_semantics() -> void:
	var h := _make_harness(6, 0)
	var webley : Node = h.webley
	var state : Node = h.state

	webley.unload()
	assert_true(state.is_reloading, "unload() must hold the character reload flag")
	assert_null(state.reloading_item, "unload() must NOT register a reloading_item: switching stays locked")

	# An abort must not touch an unload: the ReloadTimer is stopped during an
	# unload, and reloading_item being null keeps the switch hard-locked.
	webley.request_reload_abort()
	assert_true(state.is_reloading, "the abort must not clear an unload in flight")
	assert_eq(webley.current_ammo, 6, "the abort must not disturb the unload")

	# The unload boundary is the UnloadTimer timeout; it does not emit the
	# reload stage signal, so wait out the 0.25 s unload time instead.
	await wait_seconds(0.6)
	assert_eq(webley.current_ammo, 0, "the unload must empty the weapon at its boundary")
	assert_eq(h.inventory.tiny_items[AmmoResource], 6, "the unload must return the rounds to the inventory")
	assert_false(state.is_reloading, "the unload boundary must clear is_reloading")
