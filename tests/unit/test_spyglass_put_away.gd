extends GutTest

## Spyglass put-away (owner feature, 2026-11-09, not 3.x parity): holding the
## spyglass action with a non-bulky mainhand item or gun first holsters the
## item through the inventory's own same-slot toggle (the landed put-away:
## lit-light extinguish per #644/c9782f05, belt stow of a belt-capable
## lantern) and raises the zoom; on release the zoom lowers and the SAME
## item returns to the mainhand through the normal equip path with its
## landed 0.5 s draw. A bulky mainhand means B does nothing at all, an
## active reload keeps its gun, and death mid-hold cancels the return
## instead of re-equipping onto a corpse. The spyglass itself is a tiny
## item and never routes through equip. Edge pins: item dropped mid-hold
## (no ghost restore) and a hotbar switch mid-hold (the switch wins).

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const UI_SCENE := preload("res://scenes/ui/game_ui.tscn")
const SPYGLASS_ITEM := preload("res://resources/tiny_items/spyglass.tres")
const SPYGLASS_ACTION := "ablty|binocs_spyglass"
const ZOOM_CONTROLLER := preload("res://scenes/characters/player/spyglass_zoom_controller.gd")
const WEBLEY_SCENE := "res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn"
const CANDLE_LANTERN_SCENE := "res://scenes/objects/pickable_items/equipment/tool/light-sources/candle_lantern/candle_lantern.tscn"
const DARK_LANTERN_SCENE := "res://scenes/objects/pickable_items/equipment/tool/light-sources/belt_clip_dark_lantern/dark_lantern.tscn"

const CAMERA_BASELINE_FOV : float = 75.0
const ZOOM_FOV : float = 30.0
const ZOOM_FRAMES : int = 40
const RESTORE_FRAMES : int = 120
## The landed 0.5 s equip draw plus margin.
const DRAW_WAIT := 0.7

var _world : Node3D
var _game : Game
var _saved_game : Game
var _saved_dead : bool


func before_each() -> void:
	# Same stub set as test_spyglass_zoom / test_belt_hook: the real player
	# scene ticks interact_controller, which reads ui_root every frame.
	_saved_game = GameManager.game
	_saved_dead = GameManager.is_player_dead
	GameManager.is_player_dead = false
	_game = Game.new()
	GameManager.game = _game
	var ui : Node = UI_SCENE.instantiate()
	add_child_autofree(ui)
	_game.ui_root = ui


func after_each() -> void:
	GameManager.game = _saved_game
	GameManager.is_player_dead = _saved_dead
	if Input.is_action_pressed(SPYGLASS_ACTION):
		Input.action_release(SPYGLASS_ACTION)
	if _world != null:
		_world.free()
		_world = null
	if _game != null:
		_game.free()
		_game = null


func _physics_frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame
	_tolerate_harness_noise()


func _tolerate_harness_noise() -> void:
	# Harness-only engine noise, same discipline as test_light_stow_extinguish.gd
	# and test_belt_hook.gd: the lantern cone re-triangulation, the reparent
	# parent chatter, the landed game_ui anchors warning, and the webley
	# scene chain's invalid resource UIDs (the effects .import churn is
	# another lane's live edit).
	for e in gut.error_tracker.get_current_test_errors():
		var text := String(e.code) + " " + String(e.rationale)
		if text.contains("Too few vertices per face") \
				or text.contains("already has a parent") \
				or text.contains("p_child->data.parent") \
				or text.contains("non-equal opposite anchors") \
				or text.contains("invalid UID") \
				or text.contains("using text path instead"):
			e.handled = true


func _spawn_player_with_zoom() -> Node:
	# Same runtime wiring as Game.spawn_player: the controller node under the
	# player's main camera, then the 3-arg setup. The world is named
	# TestWorld so inventory._drop_item can route a dropped item into it.
	_world = Node3D.new()
	_world.name = "TestWorld"
	add_child_autofree(_world)
	var player : Node = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_world.add_child(player)
	var camera := player.get_node("ModelRoot/MainCamera") as Camera3D
	var zoom_controller : Node = ZOOM_CONTROLLER.new()
	zoom_controller.name = "SpyglassZoomController"
	camera.add_child(zoom_controller)
	zoom_controller.setup(camera, player.get_node("Inventory") as Inventory,
		player.get_node("PlayerController") as PlayerController)
	player.inventory.tiny_items[SPYGLASS_ITEM] = 1
	await _physics_frames(2)
	return player


func _zoom_controller(player : Node) -> Node:
	return player.get_node("ModelRoot/MainCamera/SpyglassZoomController")


func _inventory(player : Node) -> Inventory:
	return player.get_node("Inventory") as Inventory


func _spawn_item(scene_path : String) -> Node:
	var item : Node = (load(scene_path) as PackedScene).instantiate()
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	_world.add_child(item)
	await _physics_frames(1)
	return item


## The landed mainhand equip harness (same shape as test_belt_hook): direct
## field writes plus the hand-root parenting, no 0.5 s draw await.
func _equip_mainhand(player : Node, item : Node, slot : int = 0) -> void:
	var inv := _inventory(player)
	inv.hotbar[slot] = item
	item.item_state = GlobalConsts.ItemState.EQUIPPED
	inv.current_mainhand_equipment = item
	player.main_hand_root.add_child(item)


func _hold_b() -> void:
	Input.action_press(SPYGLASS_ACTION)


func _release_b() -> void:
	Input.action_release(SPYGLASS_ACTION)


func test_b_hold_with_gun_mainhand_holsters_zooms_and_returns_the_gun() -> void:
	var player : Node = await _spawn_player_with_zoom()
	var gun : Node = await _spawn_item(WEBLEY_SCENE)
	_equip_mainhand(player, gun)
	var inv := _inventory(player)
	var pc : PlayerController = player.get_node("PlayerController")
	var camera : Camera3D = player.get_node("ModelRoot/MainCamera")

	_hold_b()
	await _physics_frames(3)
	assert_null(inv.current_mainhand_equipment, "the put-away emptied the mainhand")
	assert_eq(inv.hotbar[0], gun, "the gun kept its own hotbar slot")
	assert_eq(gun.get_parent(), null, "the gun left the hand root unparented, holstered")
	assert_true(_zoom_controller(player)._zooming, "the zoom raised after the put-away")
	assert_eq(pc.camera_look_mod, 0.25, "the zoomed look is the 0.25 seam value")

	await _physics_frames(ZOOM_FRAMES)
	assert_almost_eq(camera.fov, ZOOM_FOV, 0.05, "the fov converged to the zoom target")
	assert_null(inv.current_mainhand_equipment,
		"the gun stays holstered past the draw window, no equip was armed by the put-away")

	_release_b()
	await _physics_frames(2)
	assert_eq(pc.camera_look_mod, 1.0, "the release restored the un-scaled look")
	await get_tree().create_timer(DRAW_WAIT).timeout
	await _physics_frames(2)
	assert_eq(inv.current_mainhand_equipment, gun, "release re-equipped the SAME gun node")
	assert_eq(gun.get_parent(), player.main_hand_root, "the gun is back in the hand root")
	await _physics_frames(RESTORE_FRAMES)
	assert_almost_eq(camera.fov, CAMERA_BASELINE_FOV, 0.05, "the fov eased back to the baseline")


func test_b_hold_with_non_bulky_equipment_mainhand_holsters_and_returns() -> void:
	var player : Node = await _spawn_player_with_zoom()
	var lantern : Node = await _spawn_item(CANDLE_LANTERN_SCENE)
	_equip_mainhand(player, lantern)
	var inv := _inventory(player)

	_hold_b()
	await _physics_frames(3)
	assert_null(inv.current_mainhand_equipment, "the non-bulky item holstered")
	assert_eq(inv.hotbar[0], lantern, "the item kept its hotbar slot")
	assert_true(_zoom_controller(player)._zooming, "the zoom raised")

	_release_b()
	await get_tree().create_timer(DRAW_WAIT).timeout
	await _physics_frames(2)
	assert_eq(inv.current_mainhand_equipment, lantern, "the same item returned to the mainhand")
	assert_eq(lantern.get_parent(), player.main_hand_root, "the item is back in the hand root")


func test_bulky_mainhand_does_nothing_at_all() -> void:
	var player : Node = await _spawn_player_with_zoom()
	var bulky : Node = await _spawn_item(WEBLEY_SCENE)
	bulky.item_size = GlobalConsts.ItemSize.SIZE_BULKY
	var inv := _inventory(player)
	inv.equip_bulky_item(bulky)
	await _physics_frames(1)
	assert_eq(inv.bulky_equipment, bulky, "precondition: the bulky item is the mainhand")
	var camera : Camera3D = player.get_node("ModelRoot/MainCamera")
	var pc : PlayerController = player.get_node("PlayerController")

	_hold_b()
	await _physics_frames(ZOOM_FRAMES)
	assert_almost_eq(camera.fov, CAMERA_BASELINE_FOV, 0.001,
		"bulky mainhand: no zoom raise, the fov never moved")
	assert_eq(pc.camera_look_mod, 1.0, "bulky mainhand: the look seam never scaled")
	assert_false(_zoom_controller(player)._zooming, "bulky mainhand: no zoom state")
	assert_eq(inv.bulky_equipment, bulky, "bulky mainhand: the item was never put away")
	assert_eq(bulky.get_parent(), player.main_hand_root, "the bulky item stayed in hand")

	_release_b()
	await _physics_frames(3)
	assert_eq(inv.bulky_equipment, bulky, "release with bulky mainhand: still equipped, nothing restored")


func test_lit_lantern_extinguishes_on_put_away_and_stays_out_on_return() -> void:
	var player : Node = await _spawn_player_with_zoom()
	var lantern : Node = await _spawn_item(CANDLE_LANTERN_SCENE)
	_equip_mainhand(player, lantern)
	lantern.light()
	assert_true(lantern.is_lit, "precondition: the lantern burns")
	var inv := _inventory(player)

	_hold_b()
	await _physics_frames(3)
	assert_false(lantern.is_lit,
		"the put-away extinguished the lit light (the #644 stow seam applies)")
	assert_false(lantern.firelight.visible, "the flame light is off after the put-away")
	assert_null(inv.current_mainhand_equipment, "the lantern holstered")

	_release_b()
	await get_tree().create_timer(DRAW_WAIT).timeout
	await _physics_frames(2)
	assert_eq(inv.current_mainhand_equipment, lantern, "the lantern returned on release")
	assert_false(lantern.is_lit, "the returned lantern stays extinguished")
	assert_false(lantern.firelight.visible, "the returned lantern does not relight")


func test_belt_capable_lantern_stows_to_the_belt_lit_and_returns_lit() -> void:
	var player : Node = await _spawn_player_with_zoom()
	var lantern : Node = await _spawn_item(DARK_LANTERN_SCENE)
	_equip_mainhand(player, lantern)
	lantern.light()
	assert_true(lantern.is_lit, "precondition: the belt lantern burns")
	var inv := _inventory(player)

	_hold_b()
	await _physics_frames(3)
	assert_eq(lantern.get_parent(), player.get("belt_position"),
		"the put-away stowed the belt-capable lantern onto the belt hook")
	assert_eq(inv.belt_item, lantern, "the belt hook owns the lantern")
	assert_true(lantern.is_in_belt, "the lantern carries the belt-stow flag")
	assert_true(lantern.is_lit, "the belt-hook lantern keeps burning (the #644 belt exception)")
	assert_null(inv.current_mainhand_equipment, "the lantern left the hand")

	_release_b()
	await get_tree().create_timer(DRAW_WAIT).timeout
	await _physics_frames(2)
	assert_eq(inv.current_mainhand_equipment, lantern, "the lantern returned to the mainhand")
	assert_eq(lantern.get_parent(), player.main_hand_root, "the lantern is back in the hand root")
	assert_false(lantern.is_in_belt, "the lantern left the belt hook")
	assert_null(inv.belt_item, "the belt hook is free again")
	assert_true(lantern.is_lit, "the returned lantern is still burning")


func test_death_mid_zoom_ends_the_zoom_and_cancels_the_return() -> void:
	var player : Node = await _spawn_player_with_zoom()
	var gun : Node = await _spawn_item(WEBLEY_SCENE)
	_equip_mainhand(player, gun)
	var inv := _inventory(player)

	_hold_b()
	await _physics_frames(3)
	assert_null(inv.current_mainhand_equipment, "precondition: the gun holstered")
	assert_true(_zoom_controller(player)._zooming, "precondition: zoomed")

	GameManager.is_player_dead = true
	await _physics_frames(3)
	assert_false(_zoom_controller(player)._zooming, "death ends the zoom hold")
	assert_eq(_zoom_controller(player)._holstered_slot, -1, "death cancels the pending return")

	_release_b()
	await get_tree().create_timer(DRAW_WAIT).timeout
	await _physics_frames(2)
	assert_null(inv.current_mainhand_equipment, "no item re-equips onto a corpse")
	assert_eq(inv.hotbar[0], gun, "the holstered gun is untouched in its slot")


func test_item_dropped_mid_zoom_does_not_restore_a_ghost() -> void:
	var player : Node = await _spawn_player_with_zoom()
	var gun : Node = await _spawn_item(WEBLEY_SCENE)
	_equip_mainhand(player, gun)
	var inv := _inventory(player)

	_hold_b()
	await _physics_frames(3)
	assert_null(inv.current_mainhand_equipment, "precondition: the gun holstered")

	# The holstered gun leaves the inventory mid-hold (dropped to the world).
	var dropped : Node = inv.drop_hotbar_slot(0)
	assert_eq(dropped, gun, "the drop released the holstered gun node")

	_release_b()
	await get_tree().create_timer(DRAW_WAIT).timeout
	await _physics_frames(2)
	assert_null(inv.current_mainhand_equipment, "the return skipped: the item left its slot")
	assert_null(inv.hotbar[0], "the slot stays empty, no ghost restore")
	assert_true(is_instance_valid(gun), "the dropped gun lives in the world")


func test_hotbar_switch_mid_zoom_wins_over_the_return() -> void:
	var player : Node = await _spawn_player_with_zoom()
	var gun : Node = await _spawn_item(WEBLEY_SCENE)
	_equip_mainhand(player, gun)
	var inv := _inventory(player)

	_hold_b()
	await _physics_frames(3)
	assert_null(inv.current_mainhand_equipment, "precondition: the gun holstered")

	# A hotbar switch away mid-hold re-points the selection; the return must
	# not yank the stored item back over it.
	inv.current_mainhand_slot = 5
	await _physics_frames(1)

	_release_b()
	await get_tree().create_timer(DRAW_WAIT).timeout
	await _physics_frames(2)
	assert_eq(inv.current_mainhand_slot, 5, "the mid-hold switch stands")
	assert_null(inv.current_mainhand_equipment, "the switched-to slot stays empty")
	assert_eq(inv.hotbar[0], gun, "the stored gun stays in its slot, never double-restored")


func test_empty_hands_zoom_still_works_without_a_put_away() -> void:
	var player : Node = await _spawn_player_with_zoom()
	var inv := _inventory(player)
	var camera : Camera3D = player.get_node("ModelRoot/MainCamera")
	var pc : PlayerController = player.get_node("PlayerController")

	_hold_b()
	await _physics_frames(ZOOM_FRAMES)
	assert_almost_eq(camera.fov, ZOOM_FOV, 0.05, "empty hands: the landed zoom still raises")
	assert_eq(pc.camera_look_mod, 0.25, "empty hands: the look seam applies")
	assert_eq(_zoom_controller(player)._holstered_slot, -1, "nothing was stored for return")

	_release_b()
	await _physics_frames(RESTORE_FRAMES)
	assert_almost_eq(camera.fov, CAMERA_BASELINE_FOV, 0.05, "empty hands: release restores the fov")
	assert_null(inv.current_mainhand_equipment, "empty hands stay empty")


func test_reloading_mainhand_blocks_the_raise_and_the_put_away() -> void:
	var player : Node = await _spawn_player_with_zoom()
	var gun : Node = await _spawn_item(WEBLEY_SCENE)
	_equip_mainhand(player, gun)
	var inv := _inventory(player)
	var camera : Camera3D = player.get_node("ModelRoot/MainCamera")
	player.state.is_reloading = true

	_hold_b()
	await _physics_frames(ZOOM_FRAMES)
	assert_almost_eq(camera.fov, CAMERA_BASELINE_FOV, 0.001,
		"an active reload keeps its gun: no zoom raise")
	assert_false(_zoom_controller(player)._zooming, "no zoom state while reloading")
	assert_eq(inv.current_mainhand_equipment, gun, "the reloading gun was never put away")
	player.state.is_reloading = false

	_release_b()
	await _physics_frames(3)
	assert_eq(inv.current_mainhand_equipment, gun, "release after a gated hold: nothing changed")
