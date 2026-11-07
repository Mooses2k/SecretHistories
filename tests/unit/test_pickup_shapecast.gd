# Tests for shapecast-based pickup (issue #736): candidate filtering goes
# through Inventory.can_pickup_item, ranking prefers the candidate with the
# smallest perpendicular distance to the camera ray (ties break toward the
# camera), and the arbitration rule lets a tiny item under the crosshair block
# hold-to-grab capture while equipment keeps the tap-picks-hold-drags split.
# Real item scenes are instantiated, matching the rest of the suite: bare
# script instances lack the scene children their _ready paths expect.
extends GutTest

const PickupResolverScript = preload("res://scenes/characters/player/pickup_resolver.gd")
const InteractControllerScript = preload("res://scenes/characters/player/interact_controller.gd")
const TinyItemScene = preload("res://scenes/objects/pickable_items/tiny/_tiny_item.tscn")
const BareItemScene = preload("res://scenes/objects/pickable_items/_pickable_item.tscn")
const KeyItemScene = preload("res://scenes/objects/pickable_items/tiny/key/key_item.tscn")
const CandleScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn")

const RAY_ORIGIN := Vector3(0.0, 1.6, 0.0)
const RAY_DIRECTION := Vector3(0.0, 0.0, -1.0)


func _make_inventory() -> Inventory:
	return add_child_autofree(Inventory.new())


func _make_item(scene : PackedScene, position : Vector3) -> PickableItem:
	var item : PickableItem = scene.instantiate()
	add_child_autofree(item)
	item.global_position = position
	return item


func _make_controller() -> Node:
	var controller = InteractControllerScript.new()
	controller.player_controller = double(PlayerController).new()
	autofree(controller)
	return controller


func _press_interact(controller : Node) -> void:
	var event := InputEventAction.new()
	event.action = &"player|interact"
	event.pressed = true
	controller._unhandled_input(event)


func test_filter_keeps_only_pickup_legal_dropped_items():
	var inventory = _make_inventory()
	var tiny = _make_item(TinyItemScene, Vector3.ZERO)
	var bare_pickable = _make_item(BareItemScene, Vector3.ONE)
	var busy_tiny = _make_item(TinyItemScene, Vector3.ONE * 2.0)
	busy_tiny.set_item_state(GlobalConsts.ItemState.BUSY)

	var result := PickupResolverScript.filter_pick_candidates(
			[tiny, bare_pickable, busy_tiny], inventory)

	assert_eq(result.size(), 1, "only the dropped tiny item survives the filter")
	assert_eq(result[0], tiny)


func test_select_best_prefers_smallest_perpendicular_distance_to_the_ray():
	var on_ray = _make_item(TinyItemScene, Vector3(0.0, 1.6, -2.0))
	var off_ray = _make_item(TinyItemScene, Vector3(0.4, 1.6, -1.0))

	var best := PickupResolverScript.select_best(
			[off_ray, on_ray], RAY_ORIGIN, RAY_DIRECTION)

	assert_eq(best, on_ray, "the candidate on the ray beats a nearer off-ray one")


func test_select_best_tie_breaks_toward_the_camera():
	var near_hit = _make_item(TinyItemScene, Vector3(0.0, 1.6, -1.0))
	var far_hit = _make_item(TinyItemScene, Vector3(0.0, 1.6, -2.0))

	var best := PickupResolverScript.select_best(
			[far_hit, near_hit], RAY_ORIGIN, RAY_DIRECTION)

	assert_eq(best, near_hit, "equally off-ray hits pick the one closest to the camera")


func test_select_best_skips_candidates_behind_the_camera():
	var behind = _make_item(TinyItemScene, Vector3(0.0, 1.6, 2.0))

	var best := PickupResolverScript.select_best([behind], RAY_ORIGIN, RAY_DIRECTION)

	assert_null(best, "a candidate behind the camera is not under the crosshair")


func test_outranks_drag_true_only_for_tiny_and_key_items():
	assert_true(PickupResolverScript.outranks_drag(_make_item(TinyItemScene, Vector3.ZERO)))
	assert_true(PickupResolverScript.outranks_drag(_make_item(KeyItemScene, Vector3.ZERO)))
	assert_false(PickupResolverScript.outranks_drag(_make_item(CandleScene, Vector3.ZERO)))
	assert_false(PickupResolverScript.outranks_drag(_make_item(BareItemScene, Vector3.ZERO)))


func test_tiny_pickup_candidate_blocks_grab_capture():
	var controller = _make_controller()
	controller.pick_target = _make_item(TinyItemScene, Vector3.ZERO)

	_press_interact(controller)

	assert_null(controller.captured_grab_target,
			"a tiny item under the crosshair always wins pickup: no grab capture")
	assert_eq(controller.interact_state, controller.InteractState.PENDING)


func test_equipment_pickup_candidate_keeps_grab_capture():
	var controller = _make_controller()
	var grab_body := RigidBody3D.new()
	autofree(grab_body)
	controller.grab_target = grab_body
	controller.pick_target = _make_item(CandleScene, Vector3.ZERO)

	_press_interact(controller)

	assert_not_null(controller.captured_grab_target,
			"equipment keeps the timing split: tap picks, hold drags")
