# Batch D anchor for the stack record model (stack rework design, Wave S1):
# the Inventory-owned StackableStackRecord API. Pins the record lifecycle the
# model defines: add merges into a record with space and creates a second
# same-type record when full, remove decrements and destroys an empty record
# only when no hotbar slot or hand holds its representative, materialize
# spawns before it decrements, and ids are stable monotonically assigned
# integers. Save/load roundtrip of records is Wave S3 (the save format change
# is approved but not implemented yet) and is asserted with nothing here.
# The S2 call-site migration will extend these pins to the pickup and drop
# flows; for now the API-level contract is the anchor.
extends GutTest

const InventoryScript = preload("res://scenes/characters/inventory.gd")
const DAGGERS_STACK := "res://resources/inventory/stackables/daggers_stack.tres"
const CANDLES_STACK := "res://resources/inventory/stackables/candles_stack.tres"
const DAGGER_SCENE := "res://scenes/objects/pickable_items/equipment/melee/dagger/dagger.tscn"

var _tracked : Array[Node] = []


func after_each() -> void:
	for node in _tracked:
		if is_instance_valid(node):
			node.free()
	_tracked.clear()


func _make_inventory() -> Inventory:
	var inv : Inventory = InventoryScript.new()
	add_child_autofree(inv)
	return inv


func _track(node : Node) -> Node:
	_tracked.append(node)
	return node


func test_add_creates_a_record_with_count_and_monotonic_ids():
	var inv = _make_inventory()

	assert_true(inv.add_to_stack_record(DAGGERS_STACK, DAGGER_SCENE, 1),
		"adding a stackable type creates its record")
	assert_eq(inv.stack_records.size(), 1, "one record after the first add")
	var daggers : StackableStackRecord = inv.get_stack_record(0)
	assert_eq(daggers.count, 1, "the record counts the added unit")
	assert_eq(daggers.type_id, DAGGERS_STACK, "type identity is the resource path")
	assert_eq(daggers.item_scene_path, DAGGER_SCENE, "the record remembers the item scene")

	assert_true(inv.add_to_stack_record(CANDLES_STACK, DAGGER_SCENE, 1),
		"adding a second type creates its own record")
	var candles : StackableStackRecord = inv.get_stack_record(1)
	assert_eq(candles.type_id, CANDLES_STACK, "the second record is the second type")
	assert_eq(inv.records_for_type(DAGGERS_STACK).size(), 1, "type queries stay type-scoped")


func test_add_merges_into_a_record_with_space():
	var inv = _make_inventory()

	assert_true(inv.add_to_stack_record(DAGGERS_STACK, DAGGER_SCENE, 1), "first unit in")
	assert_true(inv.add_to_stack_record(DAGGERS_STACK, DAGGER_SCENE, 1), "second unit merges")
	assert_eq(inv.stack_records.size(), 1, "space in the record keeps it a single record")
	assert_eq(inv.get_stack_record(0).count, 2, "the record counts both units")


func test_add_creates_a_second_record_when_the_first_is_full():
	var inv = _make_inventory()
	assert_eq(load(DAGGERS_STACK).max_stack, 2, "precondition: daggers max out at 2")

	assert_true(inv.add_to_stack_record(DAGGERS_STACK, DAGGER_SCENE, 2), "the record fills up")
	assert_true(inv.add_to_stack_record(DAGGERS_STACK, DAGGER_SCENE, 1),
		"a full record forces a second record")
	assert_eq(inv.stack_records.size(), 2, "same-type stacks are allowed their own records")
	assert_eq(inv.get_stack_record(0).count, 2, "the first record stays full")
	assert_eq(inv.get_stack_record(1).count, 1, "the overflow lands in the new record")
	assert_eq(inv.records_for_type(DAGGERS_STACK).size(), 2, "both records report for the type")


func test_add_rejects_bad_types_bad_scenes_and_nonpositive_amounts():
	var inv = _make_inventory()

	assert_false(inv.add_to_stack_record(&"res://no_such_stack.tres", DAGGER_SCENE, 1),
		"an unknown type id fails")
	assert_false(inv.add_to_stack_record(DAGGERS_STACK, "res://no_such_scene.tscn", 1),
		"an unknown item scene fails")
	assert_false(inv.add_to_stack_record(DAGGERS_STACK, DAGGER_SCENE, 0),
		"a zero amount fails")
	assert_false(inv.add_to_stack_record(DAGGERS_STACK, DAGGER_SCENE, -1),
		"a negative amount fails")
	assert_eq(inv.stack_records.size(), 0, "failed adds create no record")


func test_add_seeds_per_item_state_and_merges_new_keys_without_overwriting():
	var inv = _make_inventory()

	assert_true(inv.add_to_stack_record(CANDLES_STACK, DAGGER_SCENE, 1, {"charges_held": 3}),
		"the record is created with its per-item state")
	assert_eq(inv.get_stack_record(0).per_item_state.get("charges_held", 0), 3,
		"a new record seeds per_item_state from the add")

	assert_true(inv.add_to_stack_record(CANDLES_STACK, DAGGER_SCENE, 1, {"color": "red"}),
		"the merge add succeeds")
	var state : Dictionary = inv.get_stack_record(0).per_item_state
	assert_eq(state.size(), 2, "new keys from the added units merge in")
	assert_eq(state.get("charges_held", 0), 3, "existing record state is not overwritten")
	assert_eq(state.get("color", ""), "red", "the new key is present after the merge")


func test_remove_decrements_and_destroys_an_unrepresented_empty_record():
	var inv = _make_inventory()
	inv.add_to_stack_record(DAGGERS_STACK, DAGGER_SCENE, 2)

	assert_true(inv.remove_from_stack_record(0, 1), "removing within count succeeds")
	assert_eq(inv.get_stack_record(0).count, 1, "the record decrements")

	assert_true(inv.remove_from_stack_record(0, 1), "removing the last unit succeeds")
	assert_eq(inv.get_stack_record(0), null,
		"an empty record with no representative is destroyed")


func test_remove_keeps_a_record_while_the_hotbar_holds_its_representative():
	var inv = _make_inventory()
	inv.add_to_stack_record(DAGGERS_STACK, DAGGER_SCENE, 1)
	var rep : EquipmentItem = _track((load(DAGGER_SCENE) as PackedScene).instantiate()) as EquipmentItem
	rep.stack_record_id = 0
	inv.hotbar[0] = rep

	assert_true(inv.remove_from_stack_record(0, 1), "the unit is removed")
	assert_eq(inv.get_stack_record(0).count, 0,
		"the record survives at count 0 while its representative is in the hotbar")

	inv.hotbar[0] = null
	inv.add_to_stack_record(CANDLES_STACK, DAGGER_SCENE, 1)
	assert_eq(inv.get_stack_record(0), null,
		"the empty unrepresented record is destroyed by the next mutation's sweep")
	assert_eq(inv.stack_records.size(), 1, "only the new record remains")


func test_remove_rejects_over_removal_unknown_ids_and_nonpositive_amounts():
	var inv = _make_inventory()
	inv.add_to_stack_record(DAGGERS_STACK, DAGGER_SCENE, 1)

	assert_false(inv.remove_from_stack_record(0, 2), "removing more than held fails")
	assert_eq(inv.get_stack_record(0).count, 1, "a failed removal does not mutate")
	assert_false(inv.remove_from_stack_record(77, 1), "an unknown record id fails")
	assert_false(inv.remove_from_stack_record(0, 0), "a zero amount fails")
	assert_false(inv.remove_from_stack_record(0, -1), "a negative amount fails")
	assert_eq(inv.get_stack_record(0).count, 1, "all failed removals leave the record")


func test_materialize_spawns_the_node_then_decrements_and_tags_it():
	var inv = _make_inventory()
	inv.add_to_stack_record(CANDLES_STACK, DAGGER_SCENE, 2)

	var unit : EquipmentItem = inv.materialize_stack_item(0)
	_track(unit)
	assert_is(unit, EquipmentItem, "materialize returns an EquipmentItem world node")
	assert_eq(unit.get_parent(), null, "the spawned node is unparented; the caller places it")
	assert_eq(unit.stack_record_id, 0, "the spawned node carries its record id")
	assert_eq(inv.get_stack_record(0).count, 1, "the record decrements after a successful spawn")
	assert_eq(inv.get_stack_record(0).item_scene_path, DAGGER_SCENE,
		"the spawned node's scene is the record's item scene")


func test_materialize_returns_null_and_keeps_records_untouched_on_failure():
	var inv = _make_inventory()

	assert_eq(inv.materialize_stack_item(77), null, "an unknown record materializes nothing")

	inv.add_to_stack_record(DAGGERS_STACK, DAGGER_SCENE, 1)
	var rep : EquipmentItem = _track((load(DAGGER_SCENE) as PackedScene).instantiate()) as EquipmentItem
	rep.stack_record_id = 0
	inv.hotbar[0] = rep
	inv.remove_from_stack_record(0, 1)

	assert_eq(inv.materialize_stack_item(0), null,
		"an empty record materializes nothing")
	assert_eq(inv.get_stack_record(0).count, 0,
		"a failed materialization does not decrement further")
	assert_ne(inv.get_stack_record(0), null,
		"the represented record survives the failed materialization")
