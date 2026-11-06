# Pins the bomb detonation hotbar cleanup (Brooks Wave 1 row 6, audit 4.5):
# bomb.gd _on_tree_exiting must clear its hotbar slot through the inventory
# API (clear_hotbar_slot_of: slot nulled, hotbar_changed emitted with the
# freed slot index), must clear the equipment reference, and must be a safe
# no-op when the bomb has no owner_character. The guard used to test a
# PROPERTY with has_method, so this cleanup never ran before the fix.
extends GutTest

const InventoryScript = preload("res://scenes/characters/inventory.gd")
const BombScript = preload("res://scenes/objects/pickable_items/equipment/consumable/bomb/bomb.gd")


class OwnerStub extends Node:
	var inventory = null


func test_tree_exiting_clears_hotbar_slot_via_inventory_api():
	var inv = add_child_autofree(InventoryScript.new())
	var bomb = autofree(BombScript.new())
	var owner_stub = autofree(OwnerStub.new())
	owner_stub.inventory = inv
	bomb.owner_character = owner_stub

	var changed_slots : Array = []
	inv.hotbar_changed.connect(func(slot): changed_slots.append(slot))

	inv.hotbar[3] = bomb
	inv.current_mainhand_equipment = bomb

	bomb._on_tree_exiting()

	assert_null(inv.hotbar[3], "the bomb's hotbar slot must be nulled on tree exit")
	assert_null(inv.current_mainhand_equipment, "the mainhand equipment reference must be cleared")
	assert_eq(changed_slots, [3], "the UI must be told exactly which slot was freed")


func test_tree_exiting_clears_offhand_reference_when_not_in_hotbar():
	var inv = add_child_autofree(InventoryScript.new())
	var bomb = autofree(BombScript.new())
	var owner_stub = autofree(OwnerStub.new())
	owner_stub.inventory = inv
	bomb.owner_character = owner_stub

	var changed_slots : Array = []
	inv.hotbar_changed.connect(func(slot): changed_slots.append(slot))

	inv.current_offhand_equipment = bomb
	watch_signals(inv)

	bomb._on_tree_exiting()

	assert_null(inv.current_offhand_equipment, "the offhand equipment reference must be cleared")
	assert_eq(changed_slots, [], "no hotbar slot held the bomb, so no slot-changed signal may fire")
	assert_signal_not_emitted(inv, "hotbar_changed",
		"no hotbar slot held the bomb, so no slot-changed signal may fire")


func test_tree_exiting_without_owner_character_does_not_crash():
	var bomb = autofree(BombScript.new())
	bomb.owner_character = null

	bomb._on_tree_exiting()

	assert_true(true, "a bomb with no owner_character must exit the tree without crashing")
