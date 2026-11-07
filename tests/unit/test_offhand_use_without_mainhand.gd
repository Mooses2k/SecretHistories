extends GutTest

## LAlt (playerhand|offhand_use) must work with an EMPTY mainhand.
## Owner playtest regression: item_controller._unhandled_input early-returned
## when the mainhand was null, so the offhand use block never ran and an
## offhand-only loadout (candle lantern) could never be lit.

const ItemControllerScript := preload("res://scenes/characters/player/item_controller.gd")
const InventoryScript := preload("res://scenes/characters/inventory.gd")


## Minimal EquipmentItem stand-in: the real light scripts light() in
## _use_primary(); counting the override is enough for the controller contract.
class MockLightItem extends EquipmentItem:
	var use_primary_calls : int = 0
	var is_lit : bool = false

	func _use_primary() -> void:
		use_primary_calls += 1
		is_lit = true


func _make_controller(inventory : Inventory) -> Node:
	var root := Node.new()
	add_child_autofree(root)
	var controller = ItemControllerScript.new()
	root.add_child(controller)
	controller.inventory = inventory
	return controller


func _press(controller : Node, action : StringName, pressed : bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	controller._unhandled_input(event)


func test_offhand_use_lights_lantern_with_empty_mainhand():
	var inventory : Inventory = InventoryScript.new()
	var controller := _make_controller(inventory)
	var lantern := MockLightItem.new()
	inventory.current_offhand_equipment = lantern

	_press(controller, &"playerhand|offhand_use", true)

	assert_eq(lantern.use_primary_calls, 1, "the offhand item's use_primary ran")
	assert_true(lantern.is_lit, "the lantern lit with an empty mainhand")


func test_offhand_use_lights_lantern_with_freed_mainhand():
	var inventory : Inventory = InventoryScript.new()
	var controller := _make_controller(inventory)
	var dying := MockLightItem.new()
	inventory.current_mainhand_equipment = dying
	dying.free()
	var lantern := MockLightItem.new()
	inventory.current_offhand_equipment = lantern

	_press(controller, &"playerhand|offhand_use", true)

	assert_eq(lantern.use_primary_calls, 1, "the offhand item's use_primary ran past a freed mainhand")
	assert_true(lantern.is_lit, "the lantern lit with a freed mainhand")
	assert_null(inventory.current_mainhand_equipment, "the freed mainhand reference was cleared")


func test_mainhand_use_still_works():
	var inventory : Inventory = InventoryScript.new()
	var controller := _make_controller(inventory)
	var main_item := MockLightItem.new()
	inventory.current_mainhand_equipment = main_item

	_press(controller, &"playerhand|mainhand_use", true)

	assert_eq(main_item.use_primary_calls, 1, "the mainhand item still receives use_primary")
