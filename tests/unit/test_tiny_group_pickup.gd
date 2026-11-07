# Tests for tiny item pickup (issue #735): a larger pickup zone driven by a
# tiny-only candidate filter, and Receiver-style group pickup that vacuums
# same-kind items around the anchor (TinyItemData resource identity for
# TinyItem, key id for KeyItem). Real item scenes are instantiated, matching
# the rest of the suite.
extends GutTest

const PickupResolverScript = preload("res://scenes/characters/player/pickup_resolver.gd")
const InteractControllerScript = preload("res://scenes/characters/player/interact_controller.gd")
const TinyItemScene = preload("res://scenes/objects/pickable_items/tiny/_tiny_item.tscn")
const KeyItemScene = preload("res://scenes/objects/pickable_items/tiny/key/key_item.tscn")
const CandleScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn")


func _make_inventory() -> Inventory:
	var inventory = add_child_autofree(Inventory.new())
	# add_item asserts on a null character; a double satisfies it without the
	# full humanoid rig.
	inventory.character = double(HumanoidCharacter).new()
	autofree(inventory.character)
	return inventory


func _make_item(scene : PackedScene, position : Vector3) -> PickableItem:
	var item : PickableItem = scene.instantiate()
	# Mute pickup audio: the temp player in play_pickup_sound is positioned
	# before being added to the tree, which raises an engine error in tests.
	item.item_drop_sound = null
	add_child_autofree(item)
	item.global_position = position
	return item


func _make_controller() -> Node:
	var controller = InteractControllerScript.new()
	controller.player_controller = double(PlayerController).new()
	var grab_cast := RayCast3D.new()
	add_child_autofree(grab_cast)
	controller.grab_cast = grab_cast
	autofree(controller)
	return controller


func test_tiny_only_filter_keeps_tiny_and_key_items():
	var inventory = _make_inventory()
	var tiny = _make_item(TinyItemScene, Vector3.ZERO)
	var key = _make_item(KeyItemScene, Vector3.ONE)
	var candle = _make_item(CandleScene, Vector3.ONE * 2.0)

	var result := PickupResolverScript.filter_pick_candidates(
			[tiny, key, candle], inventory, true)

	assert_eq(result.size(), 2, "tiny-only filtering drops equipment candidates")
	assert_true(result.has(tiny))
	assert_true(result.has(key))


func test_group_kind_matches_only_the_same_tiny_item_data():
	var data := TinyItemData.new()
	var other_data := TinyItemData.new()
	var same_kind = _make_item(TinyItemScene, Vector3.ZERO)
	(same_kind as TinyItem).item_data = data
	var other_kind = _make_item(TinyItemScene, Vector3.ONE)
	(other_kind as TinyItem).item_data = other_data

	assert_true(PickupResolverScript.matches_group_kind(same_kind, data, -1))
	assert_false(PickupResolverScript.matches_group_kind(other_kind, data, -1))
	assert_false(PickupResolverScript.matches_group_kind(same_kind, null, -1))


func test_group_kind_matches_the_same_key_id():
	var key_a = _make_item(KeyItemScene, Vector3.ZERO)
	key_a.key_id = 3
	var key_b = _make_item(KeyItemScene, Vector3.ONE)
	key_b.key_id = 7

	assert_true(PickupResolverScript.matches_group_kind(key_a, null, 3))
	assert_false(PickupResolverScript.matches_group_kind(key_b, null, 3))
	assert_false(PickupResolverScript.matches_group_kind(key_a, null, -1),
			"a key id of -1 matches nothing")


func test_group_pickup_collects_same_kind_items_around_the_anchor():
	var controller = _make_controller()
	var inventory = _make_inventory()
	controller.inventory = inventory
	var data := TinyItemData.new()
	var anchor = _make_item(TinyItemScene, Vector3.ZERO)
	(anchor as TinyItem).item_data = data
	var sibling = _make_item(TinyItemScene, Vector3(0.5, 0.0, 0.0))
	(sibling as TinyItem).item_data = data
	var other_kind = _make_item(TinyItemScene, Vector3(0.0, 0.5, 0.0))
	(other_kind as TinyItem).item_data = TinyItemData.new()

	controller.pick_target = anchor
	controller.pick_item()
	controller._collect_pending_tiny_group()

	assert_eq(inventory.tiny_items[data], 2,
			"the anchor and its same-kind sibling were both collected")
	assert_false(inventory.tiny_items.has((other_kind as TinyItem).item_data),
			"a different tiny kind stays in the world")


func test_anchor_without_kind_data_collects_alone():
	var controller = _make_controller()
	var inventory = _make_inventory()
	controller.inventory = inventory
	var anchor = _make_item(TinyItemScene, Vector3.ZERO)
	(anchor as TinyItem).item_data = null
	var bystander = _make_item(TinyItemScene, Vector3(0.5, 0.0, 0.0))
	(bystander as TinyItem).item_data = TinyItemData.new()

	# The capture step alone: add_item rejects null-data tiny items, so the
	# full pick path is inventory territory, not group-pickup territory.
	controller._capture_tiny_group(anchor)
	controller._collect_pending_tiny_group()

	assert_null(controller._pending_group_data, "no kind data is captured")
	assert_eq(controller._pending_group_key_id, -1, "no key kind is captured")
	assert_true(inventory.tiny_items.is_empty(),
			"no kind data means no group vacuum; the bystander stays in the world")
