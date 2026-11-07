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
	_free_delivered_candles()


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
