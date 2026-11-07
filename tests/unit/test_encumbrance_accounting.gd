# Batch D anchor for the two encumbrance seams (stack rework design, section 3):
# encumbrance is only ever written by the full recount, at the ADD seam and the
# REMOVE seam. Pins the recount composition over inventory content (hotbar
# items by size weight, record counts through their representative, bulky
# equipment) and that every S1 mutation site recomputes: the record API, the
# pickup merge, the medical consolidation stack branch, and the drop path.
extends GutTest

const InventoryScript = preload("res://scenes/characters/inventory.gd")
const EquipmentItemScript = preload("res://scenes/objects/pickable_items/equipment/equipment_item.gd")
const MedicalItemScript = preload("res://scenes/objects/pickable_items/equipment/consumable/medical/_medical_item.gd")
const CANDLES_STACK := "res://resources/inventory/stackables/candles_stack.tres"
const DAGGER_SCENE := "res://scenes/objects/pickable_items/equipment/melee/dagger/dagger.tscn"
const EQUIPMENT_ITEM_SCENE := "res://scenes/objects/pickable_items/equipment/_equipment_item.tscn"
const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"

var _world : Node3D
var _game : Game
var _ui : GameUI
var _hud : HUD
var _saved_game : Game
var _tracked : Array[Node] = []


func before_each() -> void:
	# Headless stub set for the drop-path test (inventory drops need game.level
	# or the TestWorld fallback); mirrors test_throw_scenario's harness.
	_saved_game = GameManager.game
	_world = Node3D.new()
	_world.name = "TestWorld"
	add_child(_world)


func after_each() -> void:
	_world.free()
	for node in _tracked:
		if is_instance_valid(node):
			node.free()
	_tracked.clear()
	if is_instance_valid(_game):
		_game.free()
	if is_instance_valid(_ui):
		_ui.free()
	if is_instance_valid(_hud):
		_hud.free()
	_game = null
	_ui = null
	_hud = null
	GameManager.game = _saved_game


func _make_inventory() -> Inventory:
	var inv : Inventory = InventoryScript.new()
	add_child_autofree(inv)
	return inv


func _make_item(size : GlobalConsts.ItemSize, stack_res : StackableResource) -> EquipmentItem:
	var item : EquipmentItem = EquipmentItemScript.new()
	item.item_size = size
	item.stackable_resource = stack_res
	_tracked.append(item)
	return item


func test_recount_sums_hotbar_items_records_and_bulky():
	var inv = _make_inventory()

	inv.hotbar[0] = _make_item(GlobalConsts.ItemSize.SIZE_MEDIUM, null)
	inv.hotbar[1] = _make_item(GlobalConsts.ItemSize.SIZE_SMALL, null)

	inv.add_to_stack_record(CANDLES_STACK, DAGGER_SCENE, 3)
	var record_rep : EquipmentItem = _make_item(GlobalConsts.ItemSize.SIZE_MEDIUM, StackableResource.new())
	record_rep.stack_record_id = 0
	inv.hotbar[2] = record_rep

	inv.bulky_equipment = _make_item(GlobalConsts.ItemSize.SIZE_BULKY, null)

	inv._recount_encumbrance()
	assert_eq(inv.encumbrance, 6.0,
		"1 plain medium + 0 small + 3 record units + bulky 2")


func test_small_items_and_tiny_items_contribute_nothing():
	var inv = _make_inventory()
	inv.hotbar[0] = _make_item(GlobalConsts.ItemSize.SIZE_SMALL, null)
	inv.tiny_items["probe"] = 5

	inv._recount_encumbrance()
	assert_eq(inv.encumbrance, 0.0,
		"small items weigh 0 and tiny items are amount-tracked only (owner decision 1)")


func test_add_to_stack_record_recounts_encumbrance_upward():
	var inv = _make_inventory()
	var rep : EquipmentItem = _make_item(GlobalConsts.ItemSize.SIZE_MEDIUM, StackableResource.new())
	inv.hotbar[0] = rep

	assert_true(inv.add_to_stack_record(CANDLES_STACK, DAGGER_SCENE, 1), "the record is created")
	assert_eq(inv.encumbrance, 1.0, "the untagged representative counts as its own unit")

	rep.stack_record_id = 0
	assert_true(inv.add_to_stack_record(CANDLES_STACK, DAGGER_SCENE, 1), "the second unit merges")
	assert_eq(inv.encumbrance, 2.0, "the record's count drives the recount through its representative")


func test_remove_from_stack_record_recounts_encumbrance_downward():
	var inv = _make_inventory()
	var rep : EquipmentItem = _make_item(GlobalConsts.ItemSize.SIZE_MEDIUM, StackableResource.new())
	rep.stack_record_id = 0
	inv.hotbar[0] = rep
	inv.add_to_stack_record(CANDLES_STACK, DAGGER_SCENE, 2)
	assert_eq(inv.encumbrance, 2.0, "precondition: the record counts 2 units")

	assert_true(inv.remove_from_stack_record(0, 1), "one unit removed")
	assert_eq(inv.encumbrance, 1.0, "the remove seam recounts downward")

	assert_true(inv.remove_from_stack_record(0, 1), "the last unit removed")
	assert_eq(inv.encumbrance, 0.0, "an emptied record weighs nothing while represented")


func test_materialize_counts_nothing_until_the_node_is_placed():
	var inv = _make_inventory()
	inv.add_to_stack_record(CANDLES_STACK, DAGGER_SCENE, 2)
	assert_eq(inv.encumbrance, 0.0,
		"a record with no representative in the hotbar or hands weighs nothing yet")

	var unit : EquipmentItem = inv.materialize_stack_item(0)
	assert_eq(inv.encumbrance, 0.0, "the materialized node is unparented and not counted")
	assert_eq(unit.get_parent(), null, "the caller places the spawned node")

	# The record model reads the representative's size; the test promotes the
	# spawned dagger scene instance to a medium stackable to exercise the weight.
	unit.item_size = GlobalConsts.ItemSize.SIZE_MEDIUM
	inv.hotbar[0] = unit
	inv._recount_encumbrance()
	assert_eq(inv.encumbrance, 1.0, "the placed representative counts its record's remaining unit")
	unit.free()


func test_pickup_merge_merges_into_the_same_record():
	# Real scene instances: identity is the StackableResource .tres path,
	# recovered from the scene's stored state (the runtime instance's resource
	# is a local_to_scene duplicate with an empty resource_path).
	var inv = _make_inventory()
	var first : EquipmentItem = (load(DAGGER_SCENE) as PackedScene).instantiate()
	_tracked.append(first)
	var second : EquipmentItem = (load(DAGGER_SCENE) as PackedScene).instantiate()
	_tracked.append(second)

	inv.hotbar[0] = first
	inv._tag_new_stack_record(first)
	assert_eq(inv.stack_records.size(), 1, "precondition: the first dagger owns one record")
	assert_eq(first.stack_record_id, 0, "the placed node is tagged as the record's representative")

	assert_true(inv.handle_stackable_items(second), "the same-type pickup merges into the record")
	assert_eq(inv.stack_records.size(), 1, "no second record for the same type under max_stack")
	assert_eq(inv.stack_records[0].count, 2, "the record's count rose to 2")
	assert_true(second.is_queued_for_deletion(), "the absorbed node is freed after the count rose")
	second.free()


func test_medical_consolidation_frees_the_unit_without_touching_encumbrance():
	var inv = _make_inventory()
	var container := _make_container(3, 10)
	_tracked.append(container)
	inv.hotbar[0] = container
	inv._recount_encumbrance()
	assert_eq(inv.encumbrance, 1.0, "precondition: the container counts once")

	var incoming := _make_incoming(4)

	assert_true(inv.handle_medical_consolidation(incoming), "the consolidation succeeds")
	assert_eq(container.charges_held, 7, "charges absorbed min(space, heal)")
	assert_eq(inv.encumbrance, 1.0,
		"consolidation frees an unowned floor node and writes no encumbrance (T4)")
	incoming.free()


func test_drop_hotbar_slot_recounts_encumbrance_downward():
	_game = Game.new()
	_game.level = null   # inventory._drop_item falls back to the TestWorld ancestor
	_ui = GameUI.new()
	_hud = HUD.new()
	var indicators : Array[TextureRect] = [
		TextureRect.new(), TextureRect.new(), TextureRect.new(),
	]
	for indicator in indicators:
		_hud.add_child(indicator)
	_hud.indicators = indicators
	_ui.hud_root = _hud
	_game.ui_root = _ui
	GameManager.game = _game
	var player : Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_world.add_child(player)
	for i in 5:
		await get_tree().physics_frame

	var inv : Inventory = player.get_node("Inventory")
	inv._recount_encumbrance()
	var baseline : float = inv.encumbrance

	# A real scene instance: the drop adds it to the tree, so its pickup
	# markers must exist (a bare script node would error in _ready).
	var item : EquipmentItem = (load(EQUIPMENT_ITEM_SCENE) as PackedScene).instantiate()
	assert_eq(item.item_size, GlobalConsts.ItemSize.SIZE_MEDIUM, "precondition: the base scene is a medium item")
	inv.hotbar[0] = item
	inv._recount_encumbrance()
	assert_eq(inv.encumbrance, baseline + 1.0, "the placed medium item counts once")

	inv.drop_hotbar_slot(0)
	assert_eq(inv.hotbar[0], null, "the drop clears the slot")
	assert_eq(inv.encumbrance, baseline, "the remove seam recounts the dropped unit away")
	assert_eq(item.get_parent(), _world, "the dropped item landed under the TestWorld fallback")


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
