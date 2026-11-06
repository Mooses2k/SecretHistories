# Repro test for audit Finding 1.2 (light-pickup slot overwrite):
# picking up a light while slot 0 (the mainhand slot) is empty and slot 1 is
# occupied used to overwrite slot 1's occupant after the mainhand-slot bump.
# Expected behavior: the light falls through to the next free slot and the
# occupant survives. The bulky_equipment stub keeps the equip coroutine out of
# the test; slot bookkeeping is the subject here.
extends GutTest

const InventoryScript = preload("res://scenes/characters/inventory.gd")
const TorchScript = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/torch/torch.gd")
const EquipmentScript = preload("res://scenes/objects/pickable_items/equipment/equipment_item.gd")


func test_light_pickup_falls_through_occupied_bumped_slot():
	var inv = add_child_autofree(InventoryScript.new())
	inv.bulky_equipment = autofree(EquipmentScript.new())
	var occupant = autofree(EquipmentScript.new())
	var light = autofree(TorchScript.new())

	# Defaults after _ready: current_mainhand_slot = 0 (empty), offhand empty.
	inv.hotbar[1] = occupant

	var slot = inv.place_in_hotbar(light)

	assert_eq(inv.hotbar[1], occupant, "existing occupant of slot 1 must survive the light pickup")
	assert_ne(slot, 1, "the light must not be placed into the occupied slot")
	assert_eq(inv.hotbar[slot], light, "the light must land in the next free slot")
