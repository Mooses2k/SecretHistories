# Pins the live PLACE-state blueprint orientation contract (Brooks Wave 1
# row 8 verification, probe-backed): the throw blueprint's basis follows the
# PlaceOrigin marker (humanoid_character_base.tscn: identity basis at
# (0, 1.5, 0), so it tracks ModelRoot's yaw), NOT the rotated-facing basis
# written at throw_place_controller.gd L86/L97. That L86/L97 write does not
# survive the same _process tick: _get_place_transform() returns a
# PlaceOrigin-based transform and L88/L99 overwrite the basis unconditionally,
# in both the collision and the mousewheel branch (headless probe on the real
# player scene: blueprint basis == PlaceOrigin basis, and equal to NEITHER
# facing.rotated(UP, deg_to_rad(90)) NOR facing.rotated(UP, 90)).
# The deg_to_rad(90) fix itself is committed (f67aa424) and correct as typed
# math, but the expression it fixed is dead in the live path; dropping the
# dead write or applying the rotation on top of the origin transform is an
# owner ruling. THIS TEST MUST BE CONSCIOUSLY UPDATED if that flow changes.
extends GutTest


const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const DAGGER_SCENE := "res://scenes/objects/pickable_items/equipment/melee/dagger/dagger.tscn"
const TPC_SCRIPT := preload("res://scenes/characters/player/throw_place_controller.gd")

var _world : Node3D
var _game : Game
var _level : GameWorld
var _ui : GameUI
var _hud : HUD
var _saved_game : Game


func before_each() -> void:
	# Headless stub set (same shape as test_throw_scenario.gd): keeps the real
	# per-frame handlers error-free.
	_saved_game = GameManager.game
	_world = Node3D.new()
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
	_world.free()
	GameManager.game = _saved_game
	_game.free()
	_level.free()
	_ui.free()
	_hud.free()


func _physics_frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame


func test_place_blueprint_basis_follows_place_origin() -> void:
	var player : Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.position = Vector3(2.0, 0.0, 2.0)
	_world.add_child(player)
	_game.player = player
	await _physics_frames(5)

	var inventory : Inventory = player.get_node("Inventory")
	var dagger : EquipmentItem = (load(DAGGER_SCENE) as PackedScene).instantiate()
	dagger.name = "BasisProbeDagger"
	inventory.hotbar[0] = dagger
	inventory.current_mainhand_slot = 0
	await inventory.equip_mainhand_item()

	var controller : Node = player.get_node("PlayerController/ThrowPlaceController")
	var origin : Node3D = player.get_node("ModelRoot/PlaceOrigin")
	var state : HumanoidCharacterState = player.get_node("State")

	# No awaits from here: one synchronous block, so an engine frame cannot
	# interleave and the comparison is internally consistent.
	state.set_facing_vector(Vector3.FORWARD)
	controller.set("throw_state_mainhand", TPC_SCRIPT.ThrowState.PLACE)
	var blueprint : RigidBody3D = controller.get("place_blueprint_mainhand")
	assert_true(is_instance_valid(blueprint), "PLACE state builds the blueprint")
	controller.call("_process", 0.016)
	assert_true(
		blueprint.global_basis.is_equal_approx(origin.global_transform.basis),
		"the PLACE blueprint's basis follows PlaceOrigin (the L86/L97 rotated-facing write does not survive the same tick)")
	assert_false(
		blueprint.global_basis.is_equal_approx(state.facing.rotated(Vector3.UP, 90.0)),
		"the blueprint is not oriented by a raw 90 radian rotation")
	controller.set("throw_state_mainhand", TPC_SCRIPT.ThrowState.NONE)
	assert_false(is_instance_valid(controller.get("place_blueprint_mainhand")),
		"leaving PLACE state frees the blueprint")
