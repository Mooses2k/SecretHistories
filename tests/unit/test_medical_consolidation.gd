# Tests for handle_medical_consolidation in inventory.gd (Brooks Wave 1 row 1):
# a single-use MedicalItem is merged into the FIRST matching medical container,
# capped at min(space, heal), the incoming item is freed exactly once, and a
# failed consolidation (no container, no space) returns false without consuming
# the incoming item. Stack internals are out of scope here (stack rework is
# design-first), so all items use stackable_resource = null.
extends GutTest

const InventoryScript = preload("res://scenes/characters/inventory.gd")
const MedicalItemScript = preload("res://scenes/objects/pickable_items/equipment/consumable/medical/_medical_item.gd")


func _make_container(charges : int, max_charges : int) -> MedicalItem:
	var item = MedicalItemScript.new()
	item.max_charges_held = max_charges
	item.charges_held = charges
	item.heal_amount = 1
	item.item_name = "Container"
	return item


func _make_incoming(heal : int) -> MedicalItem:
	var item = MedicalItemScript.new()
	item.max_charges_held = 1
	item.charges_held = 1
	item.heal_amount = heal
	item.item_name = "Bandage"
	return item


func test_consolidation_fills_only_the_first_matching_container():
	var inv = InventoryScript.new()
	add_child_autofree(inv)
	var first = _make_container(3, 10)
	var second = _make_container(2, 10)
	inv.hotbar[0] = first
	inv.hotbar[1] = second
	var incoming = _make_incoming(4)

	var result = inv.handle_medical_consolidation(incoming)

	assert_true(result, "a matching container makes consolidation succeed")
	assert_eq(first.charges_held, 7, "first container gains min(space, heal) = 4")
	assert_eq(second.charges_held, 2, "second matching container is left untouched")


func test_charge_cap_is_min_space_left_heal():
	var inv = InventoryScript.new()
	add_child_autofree(inv)
	var full_case = _make_container(8, 10)
	inv.hotbar[0] = full_case
	var incoming = _make_incoming(5)

	assert_true(inv.handle_medical_consolidation(incoming), "consolidation succeeds at the cap")
	assert_eq(full_case.charges_held, 10, "heal 5 into space 2 adds only 2, capped at max")

	var exact_case = _make_container(6, 10)
	inv.hotbar[0] = exact_case
	var second_incoming = _make_incoming(4)
	assert_true(inv.handle_medical_consolidation(second_incoming), "consolidation succeeds when heal equals space")
	assert_eq(exact_case.charges_held, 10, "heal 4 into space 4 fills the container exactly")


func test_success_frees_the_incoming_item():
	var inv = InventoryScript.new()
	add_child_autofree(inv)
	inv.hotbar[0] = _make_container(3, 10)
	var incoming = _make_incoming(4)

	assert_true(inv.handle_medical_consolidation(incoming), "precondition: consolidation succeeds")
	assert_true(incoming.is_queued_for_deletion(), "the consumed bandage is queued for deletion")


func test_no_container_returns_false_without_consuming():
	var inv = InventoryScript.new()
	add_child_autofree(inv)
	var incoming = _make_incoming(4)

	assert_false(inv.handle_medical_consolidation(incoming), "no container means failure")
	assert_false(incoming.is_queued_for_deletion(), "failed consolidation does not free the item")
	assert_true(is_instance_valid(incoming), "the incoming item survives the failure")


func test_full_container_returns_false_without_consuming():
	var inv = InventoryScript.new()
	add_child_autofree(inv)
	var full = _make_container(10, 10)
	inv.hotbar[0] = full
	var incoming = _make_incoming(4)

	assert_false(inv.handle_medical_consolidation(incoming), "a container with no space is not a match")
	assert_eq(full.charges_held, 10, "the full container stays full")
	assert_false(incoming.is_queued_for_deletion(), "failed consolidation does not free the item")
