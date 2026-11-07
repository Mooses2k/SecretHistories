# Integration-style throw scenario tests (#407): the real PlayerController
# throw path and the real hurtbox impact damage entry. Two throw routes are
# covered, both observed in probes: the grab route (item not in a hand slot,
# works in-tree: state goes to DROPPED, the thrower gets a collision
# exception, thrown_by is recorded, can_spin items get the -15 spin and
# thrown_point_first items get the point aligned along the throw direction,
# clamped to the item max_speed of 12) and the hotbar route (throwing the
# equipped mainhand item drops it through the real inventory path: the hotbar
# slot is cleared, the mainhand reference is cleared, owner_character is
# cleared and the item is parented under the level). Thrown damage is pinned
# through the real Hurtbox._on_body_entered entry the engine calls on contact:
# MeleeItem applies secondary_damage1 + secondary_damage2 when can_spin and
# primary_damage1 + primary_damage2 when thrown_point_first, and the 0.25 s
# repeat cooldown keeps a second contact from damaging again.
extends GutTest

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const CULTIST_SCENE := "res://scenes/characters/cultist/neophyte.tscn"
const DAGGER_SCENE := "res://scenes/objects/pickable_items/equipment/melee/dagger/dagger.tscn"
const HATCHET_SCENE := "res://scenes/objects/pickable_items/equipment/melee/hatchet/hatchet.tscn"
const HALBERD_SCENE := "res://scenes/objects/pickable_items/equipment/melee/halberd/halberd.tscn"

var _world : Node3D
var _game : Game
var _level : GameWorld
var _ui : GameUI
var _hud : HUD
var _saved_game : Game


func before_each() -> void:
	# Headless stub set that keeps the real per-frame handlers error-free
	# (interact_controller needs ui_root.hud_root, inventory drops need
	# game.level, StackableResource needs game.player). The level stays out
	# of the tree so its @onready lookups never run.
	_saved_game = GameManager.game
	_world = Node3D.new()
	# inventory._drop_item falls back to find_parent("TestWorld") when the
	# level stub is not valid, so the world root carries that name and hotbar
	# throws drop their item in-tree like a real level would.
	_world.name = "TestWorld"
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


func _spawn_player() -> Node3D:
	var player : Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.position = Vector3(2.0, 0.0, 2.0)
	_world.add_child(player)
	_game.player = player
	await _physics_frames(5)
	return player


func _throw_from(player : Node3D, item : EquipmentItem) -> void:
	var spawn_at : Vector3 = player.global_position + Vector3(0.0, 1.0, -0.6)
	_world.add_child(item)
	item.global_position = spawn_at
	await _physics_frames(2)
	var controller : Node = player.get_node("PlayerController")
	controller.call("throw_object", item)
	await _physics_frames(2)


func _camera_forward(player : Node3D) -> Vector3:
	var camera : Camera3D = player.get_node("ModelRoot/MainCamera")
	return -camera.global_basis.z


func _assert_grab_throw_flight(player : Node3D, item : EquipmentItem) -> void:
	var forward := _camera_forward(player)
	assert_eq(item.get("item_state"), GlobalConsts.ItemState.DROPPED,
		"a thrown item is in the DROPPED state")
	assert_gt(item.linear_velocity.dot(forward), 10.0,
		"the throw impulse drives the item forward, clamped near the 12 m/s item max speed")
	assert_gt(item.angular_velocity.length(), 5.0, "a can_spin item spins at about 15 rad/s")
	assert_true(item.has_meta("thrown_by"), "the throw records thrown_by on the item")
	assert_eq(item.get_meta("thrown_by"), player, "thrown_by is the throwing player")
	assert_true(item.get_collision_exceptions().has(player),
		"the thrower is added as a collision exception")


func test_grab_thrown_dagger_flies_and_carries_the_throw_record() -> void:
	var player : Node3D = await _spawn_player()
	var dagger : EquipmentItem = (load(DAGGER_SCENE) as PackedScene).instantiate()
	dagger.name = "ThrownDagger"
	await _throw_from(player, dagger)
	_assert_grab_throw_flight(player, dagger)


func test_grab_thrown_halberd_flies_point_first_without_spin() -> void:
	var player : Node3D = await _spawn_player()
	var halberd : EquipmentItem = (load(HALBERD_SCENE) as PackedScene).instantiate()
	halberd.name = "ThrownHalberd"
	await _throw_from(player, halberd)
	assert_eq(halberd.get("item_state"), GlobalConsts.ItemState.DROPPED,
		"a thrown item is in the DROPPED state")
	assert_gt(halberd.linear_velocity.dot(_camera_forward(player)), 10.0,
		"the throw impulse drives the halberd forward")
	assert_lt(halberd.angular_velocity.length(), 1.0,
		"a thrown_point_first item gets no spin")
	assert_gt(halberd.global_basis.y.normalized().dot(_camera_forward(player).normalized()), 0.95,
		"apply_throw_logic aligns the item point along the throw direction")


func _assert_thrown_contact_damage(player : Node3D, item : EquipmentItem, expected : int) -> void:
	var cultist : Node3D = (load(CULTIST_SCENE) as PackedScene).instantiate()
	cultist.name = "ThrownTarget"
	cultist.position = Vector3(2.0, 0.0, 6.0)
	_world.add_child(cultist)
	await _physics_frames(2)
	var hurtboxes : Array = cultist.find_children("*", "Hurtbox", true, false)
	var hurtbox := hurtboxes[0] as Area3D
	var state : HumanoidCharacterState = cultist.get_node("State")
	assert_eq(item.call("get_impact_damage"), expected,
		"the thrown damage convention matches the scene's authored damages")
	hurtbox.call("_on_body_entered", item)
	await _physics_frames(1)
	assert_eq(state.durability, 100 - expected,
		"the real hurtbox contact entry applies the thrown damage once")
	hurtbox.call("_on_body_entered", item)
	await _physics_frames(1)
	assert_eq(state.durability, 100 - expected,
		"the 0.25 s impact cooldown keeps a repeated contact from damaging again")


func test_spin_thrown_dagger_deals_thrown_damage_to_a_cultist() -> void:
	var player : Node3D = await _spawn_player()
	var dagger : EquipmentItem = (load(DAGGER_SCENE) as PackedScene).instantiate()
	dagger.name = "ThrownDagger"
	await _throw_from(player, dagger)
	await _assert_thrown_contact_damage(player, dagger, 19)


func test_point_thrown_halberd_deals_thrown_damage_to_a_cultist() -> void:
	var player : Node3D = await _spawn_player()
	var halberd : EquipmentItem = (load(HALBERD_SCENE) as PackedScene).instantiate()
	halberd.name = "ThrownHalberd"
	await _throw_from(player, halberd)
	await _assert_thrown_contact_damage(player, halberd, 70)


func _equip_as_mainhand(player : Node3D, item : EquipmentItem) -> void:
	var inventory : Inventory = player.get_node("Inventory")
	inventory.hotbar[0] = item
	inventory.current_mainhand_slot = 0
	await inventory.equip_mainhand_item()


func test_hotbar_thrown_hatchet_is_dropped_through_the_inventory() -> void:
	var player : Node3D = await _spawn_player()
	var hatchet : EquipmentItem = (load(HATCHET_SCENE) as PackedScene).instantiate()
	hatchet.name = "HotbarHatchet"
	# The hotbar drop path needs a valid drop target: with the level stub
	# invalid, inventory._drop_item falls back to the TestWorld ancestor, so
	# the dropped item is in-tree and the throw impulse applies for real.
	_game.level = null
	await _equip_as_mainhand(player, hatchet)
	var inventory : Inventory = player.get_node("Inventory")
	assert_eq(inventory.current_mainhand_equipment, hatchet, "the hatchet is equipped")
	assert_eq(hatchet.get_parent(), player.main_hand_root,
		"the equipped item is parented under the MainHandRoot hold socket")
	var controller : Node = player.get_node("PlayerController")
	controller.call("throw_object", hatchet)
	# Two frames: the first frame integrates the impulse into the body
	# velocity, the second is a settled read.
	await _physics_frames(2)
	assert_eq(inventory.hotbar[0], null, "the hotbar slot is cleared by the throw drop")
	assert_eq(inventory.current_mainhand_equipment, null, "the mainhand reference is cleared")
	assert_eq(hatchet.get("item_state"), GlobalConsts.ItemState.DROPPED,
		"the thrown mainhand item is in the DROPPED state")
	assert_eq(hatchet.get("owner_character"), null,
		"the inventory drop clears owner_character")
	assert_eq(hatchet.get_parent(), _world,
		"the inventory drop parents the item under the TestWorld level target")
	assert_gt(hatchet.linear_velocity.dot(_camera_forward(player)), 10.0,
		"the hotbar throw impulse drives the dropped item forward like a grab throw")
	assert_true(hatchet.has_meta("thrown_by"), "the hotbar throw also records thrown_by")


func test_hotbar_thrown_stackable_dagger_is_dropped_through_the_inventory() -> void:
	var player : Node3D = await _spawn_player()
	var dagger : EquipmentItem = (load(DAGGER_SCENE) as PackedScene).instantiate()
	dagger.name = "HotbarDagger"
	_game.level = null
	await _equip_as_mainhand(player, dagger)
	var inventory : Inventory = player.get_node("Inventory")
	assert_eq(inventory.current_mainhand_equipment, dagger, "the dagger is equipped")
	var controller : Node = player.get_node("PlayerController")
	controller.call("throw_object", dagger)
	await _physics_frames(2)
	assert_eq(inventory.hotbar[0], null,
		"the stackable hotbar slot with an empty stack is cleared by the throw drop")
	assert_eq(inventory.current_mainhand_equipment, null, "the mainhand reference is cleared")
	assert_eq(dagger.get("item_state"), GlobalConsts.ItemState.DROPPED,
		"the thrown mainhand item is in the DROPPED state")
	assert_eq(dagger.get_parent(), _world,
		"the inventory drop parents the item under the TestWorld level target")
