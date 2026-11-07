# Integration-style hold position tests (#407): what keeps an equipped item in
# its hold socket. The mechanism observed in the code and pinned by probes:
# EquipmentItem resolves %HoldPosition (the authored item-local hold pose
# marker), equip_mainhand_item sets the item transform from get_hold_transform()
# and parents it under the character's MainHandRoot socket, and
# EquipmentItem._physics_process rewrites the transform to the hold pose every
# physics frame while the item is EQUIPPED, using the raw marker for GunItem
# and the inverse of the marker for non-guns (the documented godot #62435
# drift workaround). Observed and pinned here: every probed hold socket
# (ranged gun, melee, light) carries the marker, the per-frame rewrite keeps
# the item basis locked to the hold convention and the item origin within
# centimeters over a few physics frames, and the rewrite snaps a perturbed
# item back to the hold pose on the next frame. Observed but NOT pinned as a
# pass: under a static parent the item origin sags a few millimeters per frame
# and keeps growing (the rewrite resets position but the body's fall velocity
# survives the teleports), and under the live hand skeleton the item drifts
# with the bone motion between rewrites. Both are reported in docs/research.
extends GutTest

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const RIFLE_SCENE := "res://scenes/objects/pickable_items/equipment/ranged/martini_henry_rifle/martini_henry_rifle.tscn"
const HATCHET_SCENE := "res://scenes/objects/pickable_items/equipment/melee/hatchet/hatchet.tscn"
const LANTERN_SCENE := "res://scenes/objects/pickable_items/equipment/tool/light-sources/candle_lantern/candle_lantern.tscn"

const MAX_ORIGIN_DRIFT_OVER_A_FEW_FRAMES := 0.02

var _world : Node3D
var _game : Game
var _level : GameWorld
var _ui : GameUI
var _hud : HUD
var _saved_game : Game


func before_each() -> void:
	# Headless stub set that keeps the real per-frame handlers error-free
	# (interact_controller needs ui_root.hud_root). The level stays out of the
	# tree so its @onready lookups never run.
	_saved_game = GameManager.game
	_world = Node3D.new()
	add_child(_world)
	_game = Game.new()
	_level = GameWorld.new()
	var world_data : WorldData = WorldData.new()
	world_data.cell_type.resize(world_data.cell_count)
	_level.world_data = world_data
	_game.level = _level
	_ui = GameUI.new()
	_hud = HUD.new()
	var indicators : Array[TextureRect] = [
		TextureRect.new(), TextureRect.new(), TextureRect.new(),
	]
	_hud.indicators = indicators
	_hud.add_child(indicators[0])
	_hud.add_child(indicators[1])
	_hud.add_child(indicators[2])
	_ui.hud_root = _hud
	_game.ui_root = _ui
	GameManager.game = _game


func after_each() -> void:
	# Free the scene content first so no per-frame handler sees a torn-down
	# stub, then restore the autoload state.
	_world.free()
	GameManager.game = _saved_game
	_game.free()
	_level.free()
	_ui.free()
	_hud.free()


func _physics_frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame


func _add_holder() -> Node3D:
	var holder := Node3D.new()
	holder.name = "HoldRoot"
	holder.position = Vector3(10.0, 1.0, 2.0)
	holder.rotation = Vector3(0.0, 0.2, 0.0)
	_world.add_child(holder)
	return holder


func _expected_hold_transform(item : EquipmentItem) -> Transform3D:
	var expected : Transform3D = item.get_hold_transform()
	if not item is GunItem:
		expected = expected.inverse()
	return expected


func _assert_holds_at_pose(item : EquipmentItem, expected : Transform3D, what : String) -> void:
	assert_true(item.transform.basis.is_equal_approx(expected.basis),
		"%s: the per-frame hold rewrite keeps the item basis locked to the hold convention" % what)
	assert_lt(item.transform.origin.distance_to(expected.origin),
		MAX_ORIGIN_DRIFT_OVER_A_FEW_FRAMES,
		"%s: the per-frame hold rewrite keeps the item origin within centimeters of the hold pose" % what)


func _equip_under_holder(item : EquipmentItem) -> Transform3D:
	var holder := _add_holder()
	item.name = "HoldItem"
	holder.add_child(item)
	await _physics_frames(1)
	item.set_item_state(GlobalConsts.ItemState.EQUIPPED)
	return _expected_hold_transform(item)


func test_equipped_items_carry_a_hold_position_marker() -> void:
	var holder := _add_holder()
	for scene_path in [RIFLE_SCENE, HATCHET_SCENE, LANTERN_SCENE]:
		var item : EquipmentItem = (load(scene_path) as PackedScene).instantiate()
		item.name = "HoldItem"
		holder.add_child(item)
	# Everything stays in place until the after_each cleanup; no mid-test
	# frees, so no node leaves the tree while it is still resolving.
	await _physics_frames(2)
	var items : Array = holder.get_children()
	assert_eq(items.size(), 3, "all three hold probe items are attached")
	for item in items:
		var equipment := item as EquipmentItem
		var label : String = equipment.scene_file_path.get_file()
		assert_true(equipment.hold_position != null,
			"%s resolves its authored %%HoldPosition marker" % label)
		var hold_value : Transform3D = equipment.get_hold_transform()
		var marker_value : Transform3D = equipment.hold_position.transform
		assert_true(hold_value == marker_value,
			"%s: get_hold_transform returns the authored hold pose" % label)
	_mark_skeleton_notice_handled()


# The candle lantern scene ships an old-pose-format Skeleton3D: its first load
# in a run emits an engine deprecation notice that is unrelated to the hold
# socket under test (the scene needs an editor re-save to convert the
# skeleton; tracked in the research report). Marking that notice handled keeps
# the test scoped to the hold socket; any OTHER engine error still fails.
func _mark_skeleton_notice_handled() -> void:
	for err in get_errors():
		if err.contains_text("Skeleton uses old pose format"):
			err.handled = true


func test_hold_rewrite_keeps_gun_raw_and_nongun_inverse_poses() -> void:
	for scene_path in [RIFLE_SCENE, HATCHET_SCENE, LANTERN_SCENE]:
		var item : EquipmentItem = (load(scene_path) as PackedScene).instantiate()
		var expected := await _equip_under_holder(item)
		var gun_convention := item is GunItem
		var raw := item.get_hold_transform()
		if gun_convention:
			assert_eq(expected, raw, "a gun holds at the raw marker pose")
		else:
			assert_eq(expected, raw.inverse(),
				"a non-gun holds at the inverse of the marker pose")
		for i in 3:
			await _physics_frames(1)
			_assert_holds_at_pose(item, expected, scene_path.get_file())
		item.free()
	_mark_skeleton_notice_handled()


func test_hold_rewrite_snaps_a_perturbed_item_back() -> void:
	var item : EquipmentItem = (load(HATCHET_SCENE) as PackedScene).instantiate()
	var expected := await _equip_under_holder(item)
	await _physics_frames(1)
	item.transform = expected.translated(Vector3(0.05, 0.05, 0.05))
	await _physics_frames(1)
	_assert_holds_at_pose(item, expected, "after perturbation")


func test_real_equip_places_the_gun_under_the_main_hand_root() -> void:
	var player : Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.name = "ProbePlayer"
	player.position = Vector3(2.0, 0.0, 2.0)
	_world.add_child(player)
	_game.player = player
	await _physics_frames(5)
	var rifle : EquipmentItem = (load(RIFLE_SCENE) as PackedScene).instantiate()
	rifle.name = "HoldRifle"
	var inventory : Inventory = player.get_node("Inventory")
	inventory.hotbar[0] = rifle
	inventory.current_mainhand_slot = 0
	await inventory.equip_mainhand_item()
	assert_eq(inventory.current_mainhand_equipment, rifle, "the rifle is equipped")
	assert_eq(rifle.get_parent(), player.main_hand_root,
		"the equipped item is parented under the MainHandRoot hold socket")
	assert_eq(rifle.get("item_state"), GlobalConsts.ItemState.EQUIPPED,
		"the equipped item is in the EQUIPPED state")
	assert_true(rifle.hold_position != null, "the rifle resolves its hold marker in the hand")
