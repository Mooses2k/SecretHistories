# Pins the floor-candelabra take (fuel design doc section 7, first slice,
# owner-approved simple model): interacting with the stand's Ignite area
# hands one whole candle to the character through the normal pickup path
# (hand > hotbar), lit when the stand's fire burns and unlit otherwise. ONE
# candle per stand (owner ruling): after its take the stand keeps burning
# and further interacts play the diegetic reject cue; a failed delivery
# frees the fresh node and leaves the take untouched: nothing is lost
# (no-destroy guarantee).
# Candle kind per owner mapping: the spawning floor stands (lit and unlit)
# deliver the TALL candle item, the votive stand (does not spawn in the
# world) delivers the SMALL candle.
# The real stand scene and the real player scene are used so the authored
# Ignite wiring and the real inventory pickup path are what is under test.
# The delivery-failure case uses a rejecting Inventory subclass because the
# real inventory's no-space path reports through push_error by design and
# GUT fails tests on unexpected errors.
extends GutTest

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const FLOOR_CANDELABRA_SCENE := "res://scenes/objects/large_objects/lighting/floor_candelabra.tscn"
const UNLIT_STAND_SCENE := "res://scenes/objects/large_objects/lighting/floor_candelabra_unlit.tscn"
const VOTIVE_STAND_SCENE := "res://scenes/objects/large_objects/lighting/votive_candle_stand.tscn"
const TALL_CANDLE_SCENE := "res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle_tall.tscn"
const SMALL_CANDLE_SCENE := "res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn"
const InteractControllerScript = preload("res://scenes/characters/player/interact_controller.gd")


class StubCharacter extends Node:
	var inventory : Inventory


class RejectingInventory extends Inventory:
	func add_item(_item : PickableItem) -> bool:
		return false


var _world : Node3D
var _game : Game
var _level : GameWorld
var _ui : GameUI
var _hud : HUD
var _saved_game : Game
var _delivered_candles : Array[CandleItem] = []


func before_each() -> void:
	# Headless stub set that keeps the real per-frame handlers error-free
	# (same shape as test_throw_scenario: interact_controller needs
	# ui_root.hud_root, drops need game.level, TestWorld fallback).
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


func _spawn_player() -> Node3D:
	var player : Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.position = Vector3(2.0, 0.0, 2.0)
	_world.add_child(player)
	return player


func _spawn_stand() -> Node:
	var stand : Node = (load(FLOOR_CANDELABRA_SCENE) as PackedScene).instantiate()
	_world.add_child(stand)
	return stand


func _inventory_of(player : Node3D) -> Inventory:
	return player.get_node("Inventory") as Inventory


func _collect_candles(inv : Inventory) -> Array[CandleItem]:
	var found : Array[CandleItem] = []
	for slot in inv.hotbar:
		var item := slot as CandleItem
		if item != null and is_instance_valid(item):
			found.append(item)
	_delivered_candles.append_array(found)
	return found


func _free_delivered_candles() -> void:
	for candle : CandleItem in _delivered_candles:
		if is_instance_valid(candle):
			candle.free()
	_delivered_candles.clear()


func test_ignite_take_delivers_a_lit_candle_through_the_pickup_path() -> void:
	var player : Node3D = _spawn_player()
	var stand : Node = _spawn_stand()
	var inv : Inventory = _inventory_of(player)

	# Through the real Interactable: interact() emits character_interacted,
	# which the stand connects to the take in _ready.
	stand.get_node("Ignite").interact(player)

	var candles := _collect_candles(inv)
	assert_eq(candles.size(), 1, "one candle entered the player's inventory")
	if candles.size() == 1:
		assert_true(candles[0].is_lit,
			"a candle taken from a burning stand arrives lit")
		assert_almost_eq(candles[0].fuel.fill, 1.0, 0.0001,
			"the stand does not model per-candle burn: the taken candle is full")
		assert_eq(candles[0].scene_file_path, TALL_CANDLE_SCENE,
			"the spawning floor stand delivers the TALL candle item")
	assert_eq(stand.takes_remaining, 0, "the stand's single take is spent")
	_free_delivered_candles()


func test_take_from_an_unlit_stand_arrives_unlit() -> void:
	var player : Node3D = _spawn_player()
	var stand : Node = _spawn_stand()
	var inv : Inventory = _inventory_of(player)
	stand.firelight.visible = false

	stand.get_node("Ignite").interact(player)

	var candles := _collect_candles(inv)
	assert_eq(candles.size(), 1, "the take itself still works when unlit")
	if candles.size() == 1:
		assert_false(candles[0].is_lit,
			"a candle taken from an unlit stand arrives unlit")
	_free_delivered_candles()


func test_bare_stand_takes_nothing_and_plays_the_reject_cue() -> void:
	var player : Node3D = _spawn_player()
	var stand : Node = _spawn_stand()
	var inv : Inventory = _inventory_of(player)
	stand.takes_remaining = 0

	stand.get_node("Ignite").interact(player)

	assert_eq(_collect_candles(inv).size(), 0, "a spent stand hands out nothing")
	assert_true(stand.get_node("TakeRejectSound").playing,
		"the spent stand plays the diegetic reject cue")
	_free_delivered_candles()


func test_failed_delivery_keeps_the_candle_on_the_stand() -> void:
	var stand : Node = _spawn_stand()
	var stub_character : StubCharacter = autofree(StubCharacter.new())
	stub_character.inventory = add_child_autofree(RejectingInventory.new())

	stand.get_node("Ignite").interact(stub_character)

	assert_eq(_collect_candles(stub_character.inventory).size(), 0,
		"no candle was delivered")
	assert_eq(stand.takes_remaining, 1,
		"the no-destroy guarantee: the stand keeps its take")
	assert_true(stand.get_node("TakeRejectSound").playing,
		"the failed delivery plays the reject cue")
	_free_delivered_candles()


func test_second_take_is_rejected_and_the_stand_keeps_burning() -> void:
	var player : Node3D = _spawn_player()
	var stand : Node = _spawn_stand()
	var inv : Inventory = _inventory_of(player)

	stand.get_node("Ignite").interact(player)
	stand.get_node("Ignite").interact(player)

	assert_eq(_collect_candles(inv).size(), 1,
		"one candle per stand: the second take delivers nothing")
	assert_eq(stand.takes_remaining, 0, "the take stays spent")
	assert_true(stand.firelight.visible,
		"the stand keeps burning after its take: taking does not douse it")
	assert_true(stand.get_node("TakeRejectSound").playing,
		"the second take plays the diegetic reject cue")
	_free_delivered_candles()


func test_second_take_shakes_the_stand_mesh_and_restores_it() -> void:
	# The unmissable reject upgrade (owner playtest): the spent stand shakes
	# its baked mesh briefly, then returns it to the authored rest position.
	var player : Node3D = _spawn_player()
	var stand : Node = _spawn_stand()
	var inv : Inventory = _inventory_of(player)
	var mesh : MeshInstance3D = stand._mesh_to_shake
	var rest : Vector3 = stand._mesh_rest_position
	assert_not_null(mesh, "the stand captured a mesh to shake")

	stand.get_node("Ignite").interact(player)
	stand.get_node("Ignite").interact(player)
	assert_true(stand._reject_tween != null,
		"the rejected take starts the shake tween")
	# Headless frame deltas vary, so the visible movement is pinned by the
	# dedicated probe run (tests/probe_shake_debug.gd: the mesh leaves rest
	# during the shake); here the start plus the guaranteed restore are pinned.
	await _idle_frames(40)
	assert_almost_eq(mesh.position.x, rest.x, 0.0001, "the shake ends back at rest x")
	assert_almost_eq(mesh.position.z, rest.z, 0.0001, "the shake ends back at rest z")
	assert_eq(_collect_candles(inv).size(), 1, "sanity: the shake ran on the spent stand")
	_free_delivered_candles()


func _idle_frames(count : int) -> void:
	for i in count:
		await get_tree().process_frame


func test_ignite_zone_hugs_the_stand_and_offers_the_grab_icon() -> void:
	# Revised in the melee2 lane: the take zone was shipped as a radius 1.2 /
	# height 1.6 column centered high on the stand, which put the GRAB prompt
	# and the drag target up to a meter outside the visible candelabra (owner
	# playtest defect). The corrected zone is a snug enclosure of the stand
	# body: big enough to win the interaction ray race from any side, small
	# enough that the prompt only sits on the candelabra. The take itself is
	# unchanged: the GRAB icon stays.
	var stand : Node = _spawn_stand()
	var ignite : Interactable = stand.get_node("Ignite") as Interactable

	var shape_node : CollisionShape3D = ignite.get_node("CollisionShape3D") as CollisionShape3D
	var cylinder := shape_node.shape as CylinderShape3D
	assert_not_null(cylinder, "the take zone is a snug cylinder around the stand")
	if cylinder != null:
		assert_true(cylinder.radius <= 0.5,
			"the take zone sits on the body, not a meter out (radius " + str(cylinder.radius) + ")")
		assert_true(cylinder.height >= 1.5, "the take zone covers the stand's height")
		var bottom : float = ignite.position.y - cylinder.height / 2.0
		assert_true(bottom <= -0.9, "the zone reaches down to the stand base, so a take works from any angle")
	assert_eq(ignite.indicator_override, HUD.Indicator.GRAB,
		"the take is a grab: the crosshair shows the GRAB icon, not a generic one")


func test_interact_controller_shows_the_grab_icon_for_the_stand() -> void:
	# The real decision point is the interact controller's _process: with the
	# stand's Ignite area under the crosshair it must show GRAB (the override),
	# not the IGNITE cursor the group default would pick.
	# A RigidBody3D root: 4ca9b7b0's head bob reads the player body's
	# linear_velocity through the controller's owner, so the stub must be the
	# same body class player.tscn uses.
	var stub_root : Node = RigidBody3D.new()
	stub_root.name = "StubPlayerRoot"
	_world.add_child(stub_root)
	var parameters : Node = preload("res://scenes/characters/humanoid_character_base/humanoid_character_parameters.gd").new()
	parameters.name = "Parameters"
	stub_root.add_child(parameters)
	var input_node : Node = preload("res://scenes/characters/humanoid_character_base/humanoid_character_input.gd").new()
	input_node.name = "Input"
	stub_root.add_child(input_node)
	var state : Node = preload("res://scenes/characters/humanoid_character_base/humanoid_character_state.gd").new()
	state.name = "State"
	stub_root.add_child(state)
	state.owner = stub_root
	var model_root : Node3D = Node3D.new()
	model_root.name = "ModelRoot"
	stub_root.add_child(model_root)
	var camera : Camera3D = Camera3D.new()
	camera.name = "MainCamera"
	model_root.add_child(camera)
	# 8db35b68 made the controller's @onready demand the F1 debug light under
	# the camera: mirror player.tscn so the stub does not error.
	var debug_light : SpotLight3D = SpotLight3D.new()
	debug_light.name = "DebugLight"
	camera.add_child(debug_light)
	var interaction_cast : RayCast3D = RayCast3D.new()
	interaction_cast.name = "InteractionCast"
	interaction_cast.target_position = Vector3(0.0, 0.0, -1.7)
	interaction_cast.collide_with_areas = true
	interaction_cast.collide_with_bodies = false
	camera.add_child(interaction_cast)
	var grab_cast : RayCast3D = RayCast3D.new()
	grab_cast.name = "GrabCast"
	grab_cast.target_position = Vector3(0.0, 0.0, -1.7)
	camera.add_child(grab_cast)
	var near_cast : Area3D = Area3D.new()
	near_cast.name = "NearCast"
	camera.add_child(near_cast)
	var controller_node : Node = Node.new()
	controller_node.name = "PlayerControllerNode"
	controller_node.set_script(preload("res://scenes/characters/player/player_controller.gd"))
	stub_root.add_child(controller_node)
	controller_node.owner = stub_root
	var controller : Node = Node.new()
	controller.set_script(InteractControllerScript)
	controller_node.add_child(controller)
	# Runtime add_child does not set owner (an editor concept); the scene root
	# owns the controller in player.tscn, and the head bob reads the body
	# through it.
	controller.owner = stub_root

	# The camera looks down its -Z at the stand from a realistic interact
	# distance. The player controller's _process forces the MainCamera to the
	# 1.6 m standing height, and the snug Ignite cylinder must still catch the
	# ray there: the stand is lifted so the zone spans the camera height, and
	# the ray (1.7 m, game parity with player.tscn) enters the cylinder well
	# inside its reach.
	camera.position = Vector3(0.0, 0.9, 1.4)
	var stand : Node = _spawn_stand()
	stand.position = Vector3(0.0, 0.8, 0.0)

	await _idle_frames(5)

	var hud : HUD = GameManager.game.ui_root.hud_root
	assert_eq(hud.active_indicator, HUD.Indicator.GRAB,
		"the crosshair over the stand's take zone shows the GRAB icon")
	stand.free()


func test_unlit_spawning_variant_delivers_a_tall_unlit_candle() -> void:
	var player : Node3D = _spawn_player()
	var stand : Node = (load(UNLIT_STAND_SCENE) as PackedScene).instantiate()
	_world.add_child(stand)
	var inv : Inventory = _inventory_of(player)

	# The unlit variant hides its Ignite node, but interact() has no
	# visibility gate: toppled unlit stands stay takeable in the world.
	stand.get_node("Ignite").interact(player)

	var candles := _collect_candles(inv)
	assert_eq(candles.size(), 1, "the unlit variant hands out a candle")
	if candles.size() == 1:
		assert_eq(candles[0].scene_file_path, TALL_CANDLE_SCENE,
			"the unlit variant is a spawning floor stand: tall candle")
		assert_false(candles[0].is_lit,
			"a candle taken from the unlit variant arrives unlit")
	_free_delivered_candles()


func test_votive_stand_is_interactable_with_one_take() -> void:
	var stand : Node = (load(VOTIVE_STAND_SCENE) as PackedScene).instantiate()
	_world.add_child(stand)

	var ignite : Interactable = stand.get_node("Ignite") as Interactable
	assert_not_null(ignite, "the votive stand's Ignite area carries the Interactable script")
	assert_eq(stand.takes_remaining, 1,
		"one candle per stand, votive included")
	assert_true(ignite.is_in_group(&"IGNITE"),
		"the votive stand joins the IGNITE group like its siblings")


func test_votive_stand_delivers_the_small_candle() -> void:
	var player : Node3D = _spawn_player()
	var stand : Node = (load(VOTIVE_STAND_SCENE) as PackedScene).instantiate()
	_world.add_child(stand)
	var inv : Inventory = _inventory_of(player)

	stand.get_node("Ignite").interact(player)

	var candles := _collect_candles(inv)
	assert_eq(candles.size(), 1, "the votive stand hands out a candle")
	if candles.size() == 1:
		assert_eq(candles[0].scene_file_path, SMALL_CANDLE_SCENE,
			"the votive stand delivers the SMALL candle (owner mapping: votive = small only)")
	_free_delivered_candles()
