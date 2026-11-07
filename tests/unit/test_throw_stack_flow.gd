# Explicit headless loop for the stack throw path (T8, T9): a record-backed
# dagger stack in the player's hand is thrown one unit at a time. Each throw
# leaves the record consistent, keeps the representative in the hotbar while
# units remain, throws the materialized node instead of the representative,
# and drops the representative itself on the last unit.
extends GutTest

const DAGGER_SCENE := "res://scenes/objects/pickable_items/equipment/melee/dagger/dagger.tscn"
const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"

var _world : Node3D
var _game : Game
var _ui : GameUI
var _hud : HUD
var _saved_game : Game
var _game_stubbed : bool = false


func before_each() -> void:
	_world = Node3D.new()
	_world.name = "TestWorld"
	add_child(_world)


func after_each() -> void:
	_world.free()


func after_all() -> void:
	if is_instance_valid(_game):
		_game.free()
	if is_instance_valid(_ui):
		_ui.free()
	if is_instance_valid(_hud):
		_hud.free()
	if _game_stubbed:
		GameManager.game = _saved_game


func _game_setup() -> void:
	# Headless stub for the drop flow (mirrors test_encumbrance_accounting).
	# Idempotent: only the first call captures the real game reference.
	if not _game_stubbed:
		_saved_game = GameManager.game
		_game_stubbed = true
	if is_instance_valid(_game):
		_game.free()
	if is_instance_valid(_ui):
		_ui.free()
	if is_instance_valid(_hud):
		_hud.free()
	_game = Game.new()
	_game.level = null
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


func _spawn_player_with_dagger_stack() -> Array:
	_game_setup()
	var player : Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_world.add_child(player)
	for i in 5:
		await get_tree().physics_frame
	var inv : Inventory = player.get_node("Inventory")

	# Two daggers through the real pickup flow: the first places and tags
	# (T2/T3), the second merges into the same record (T1, daggers max 2).
	var rep : EquipmentItem = (load(DAGGER_SCENE) as PackedScene).instantiate()
	assert_true(inv.add_item(rep), "precondition: the first dagger is picked up")
	await get_tree().create_timer(0.7).timeout
	var second : EquipmentItem = (load(DAGGER_SCENE) as PackedScene).instantiate()
	assert_true(inv.add_item(second), "precondition: the second dagger merges")
	await get_tree().physics_frame
	assert_eq(inv.stack_records.size(), 1, "precondition: one record")
	assert_eq(inv.stack_records[0].count, 2, "precondition: the record holds 2 units")
	assert_eq(inv.current_mainhand_equipment, rep, "precondition: the rep is in hand")
	return [player, inv, rep]


func test_throwing_from_a_stack_throws_one_materialized_unit_and_keeps_the_rep():
	var spawned : Array = await _spawn_player_with_dagger_stack()
	var player : Node3D = spawned[0]
	var inv : Inventory = spawned[1]
	var rep : EquipmentItem = spawned[2]
	var controller = player.get_node("PlayerController")

	controller.throw_object(rep)
	await get_tree().create_timer(0.8).timeout

	assert_eq(inv.stack_records[0].count, 1, "the record lost exactly one unit")
	assert_eq(inv.hotbar[0], rep, "units remain: the representative stays in the hotbar")
	assert_eq(inv.current_mainhand_equipment, rep, "units remain: the hand re-grips the representative")
	assert_ne(inv.hotbar[0], null, "the slot survives")
	var thrown : EquipmentItem = null
	for child in _world.get_children():
		if child is EquipmentItem and child != rep and child.has_meta("thrown_by"):
			thrown = child
	assert_ne(thrown, null, "a fresh materialized node was thrown into the world")
	assert_eq(thrown.stack_record_id, 0, "the thrown node carries the record id")
	assert_eq(thrown.item_state, GlobalConsts.ItemState.DROPPED, "the thrown node is DROPPED")


func test_throwing_the_last_unit_drops_the_representative_and_destroys_the_record():
	var spawned : Array = await _spawn_player_with_dagger_stack()
	var player : Node3D = spawned[0]
	var inv : Inventory = spawned[1]
	var rep : EquipmentItem = spawned[2]
	var controller = player.get_node("PlayerController")

	# Throw down to the last unit first
	controller.throw_object(rep)
	await get_tree().create_timer(0.8).timeout
	assert_eq(inv.stack_records[0].count, 1, "precondition: one unit remains")

	controller.throw_object(inv.current_mainhand_equipment)
	await get_tree().create_timer(0.8).timeout

	assert_eq(inv.stack_records.size(), 0, "the emptied record is destroyed")
	assert_eq(inv.hotbar[0], null, "the slot is cleared")
	assert_eq(inv.current_mainhand_equipment, null, "the hand is empty")
	assert_eq(rep.get_parent(), _world, "the representative itself was thrown to the world")
	assert_eq(rep.item_state, GlobalConsts.ItemState.DROPPED, "the representative is DROPPED")
