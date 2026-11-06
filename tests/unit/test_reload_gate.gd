# Tests for the reload gate in item_controller.gd (Brooks Wave 1 row 4): the
# reload release action must call use_reload() only when the mainhand item is a
# GunItem or MedicalItem, and reject any other item type.
# A real Inventory carries the mainhand item (its get_mainhand_item cast is part
# of the seam), and the items are GUT doubles so no item scene is needed.
extends GutTest

const ItemControllerScript = preload("res://scenes/characters/player/item_controller.gd")
const InventoryScript = preload("res://scenes/characters/inventory.gd")
const GunItemScript = preload("res://scenes/objects/pickable_items/equipment/ranged/gun_item.gd")
const MedicalItemScript = preload("res://scenes/objects/pickable_items/equipment/consumable/medical/_medical_item.gd")
const MeleeItemScript = preload("res://scenes/objects/pickable_items/equipment/melee/melee_item.gd")
const PickableItemScript = preload("res://scenes/objects/pickable_items/pickable_item.gd")


func _make_inventory() -> Inventory:
	var inv = InventoryScript.new()
	add_child_autofree(inv)
	return inv


func _make_controller(inv : Inventory) -> Node:
	var controller = ItemControllerScript.new()
	controller.inventory = inv
	autofree(controller)
	return controller


func _release_reload_event() -> InputEventAction:
	var event = InputEventAction.new()
	event.action = &"player|reload"
	event.pressed = false
	return event


func test_reload_release_calls_use_reload_on_gun_item():
	var inv = _make_inventory()
	var gun = double(GunItemScript).new()
	stub(gun, "use_reload").to_do_nothing()
	autofree(gun)
	inv.current_mainhand_equipment = gun

	var controller = _make_controller(inv)
	controller._unhandled_input(_release_reload_event())
	assert_called(gun, "use_reload")  # the gate passes GunItem through


func test_reload_release_calls_use_reload_on_medical_item():
	var inv = _make_inventory()
	var medical = double(MedicalItemScript).new()
	stub(medical, "use_reload").to_do_nothing()
	autofree(medical)
	inv.current_mainhand_equipment = medical

	var controller = _make_controller(inv)
	controller._unhandled_input(_release_reload_event())
	assert_called(medical, "use_reload")  # the gate passes MedicalItem through


func test_reload_release_rejects_other_equipment_types():
	var inv = _make_inventory()
	var melee = double(MeleeItemScript).new()
	stub(melee, "use_reload").to_do_nothing()
	autofree(melee)
	inv.current_mainhand_equipment = melee

	var controller = _make_controller(inv)
	controller._unhandled_input(_release_reload_event())
	assert_not_called(melee, "use_reload")  # the gate rejects non-gun/medical equipment


func test_reload_release_rejects_a_plain_pickable():
	var inv = _make_inventory()
	var plain = double(PickableItemScript).new()
	autofree(plain)
	# A plain pickable can sit in a hotbar slot (the hotbar is Node3D typed),
	# but the mainhand getter casts to EquipmentItem, so the gate sees null and
	# must not fire anything.
	inv.hotbar[0] = plain

	var controller = _make_controller(inv)
	controller._unhandled_input(_release_reload_event())
	# A plain pickable is not EquipmentItem, so the gate sees null through the
	# mainhand getter and must not consume or repurpose the item. PickableItem
	# has no use_* methods, so spy asserts are unavailable here; state is the
	# observable instead.
	assert_eq(plain.item_state, GlobalConsts.ItemState.DROPPED, "the plain pickable stays dropped")
	assert_false(plain.is_queued_for_deletion(), "the plain pickable is not consumed")
