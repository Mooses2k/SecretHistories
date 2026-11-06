# Pins hotbar.gd L32's and-condition (Brooks Wave 1 row 9): the dimmed
# modulate (0.6) applies ONLY when a slot is BOTH not the mainhand slot AND
# not the offhand slot; the fully lit modulate (1.0) is the else branch. With
# the old `or`, exactly the two current slots (where one inequality is false)
# were dimmed as well.
# The real hotbar script runs off-tree against a real inventory and stubbed
# slot controls; the GameManager-dependent _ready() is not exercised.
extends GutTest

const HotbarScript = preload("res://scenes/ui/hotbar/hotbar.gd")
const InventoryScript = preload("res://scenes/characters/inventory.gd")
const EquipmentScript = preload("res://scenes/objects/pickable_items/equipment/equipment_item.gd")


class SlotStub extends Control:
	var stack_size : String = ""

	func set_stack_size(value : String):
		stack_size = value


func _make_hotbar():
	var inv = add_child_autofree(InventoryScript.new())
	var hotbar = autofree(HotbarScript.new())
	var vbox = autofree(VBoxContainer.new())
	vbox.name = "VBoxContainer"
	hotbar.add_child(vbox)
	for i in inv.HOTBAR_SIZE:
		inv.hotbar[i] = autofree(EquipmentScript.new())
		vbox.add_child(autofree(SlotStub.new()))
	hotbar.inventory = inv
	hotbar.initialize_hotbar()
	return { "hotbar": hotbar, "inventory": inv }


func test_only_non_current_slots_are_dimmed():
	var parts = _make_hotbar()
	var slots = parts.hotbar.get_node("VBoxContainer")
	# Fresh inventory defaults: mainhand slot 0, offhand slot 10 (hands-free).
	for i in range(parts.inventory.HOTBAR_SIZE):
		var expected_alpha := 0.6
		if i == parts.inventory.current_mainhand_slot or i == parts.inventory.current_offhand_slot:
			expected_alpha = 1.0
		# modulate is a float color channel, compare with a small delta.
		assert_almost_eq(slots.get_child(i).modulate.a, expected_alpha, 0.001,
			"slot %d: lit only when mainhand OR offhand, dimmed only when neither" % i)


func test_slot_failing_only_one_condition_stays_lit():
	var parts = _make_hotbar()
	var slots = parts.hotbar.get_node("VBoxContainer")
	# Slot 0 fails only the mainhand inequality, slot 10 only the offhand
	# inequality: with the old `or` these were dimmed, with `and` they are lit.
	assert_almost_eq(slots.get_child(0).modulate.a, 1.0, 0.001, "mainhand slot must be fully lit")
	assert_almost_eq(slots.get_child(10).modulate.a, 1.0, 0.001, "offhand slot must be fully lit")
