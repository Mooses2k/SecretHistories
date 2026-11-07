# Stack consume flows (T5, T11): refill and in-hand consumption of single-use
# medicals go through the owning Inventory's record API, never through the
# legacy per-node array. Pins: a refill with units remaining decrements the
# record and keeps the representative node; consuming the last unit clears
# the slot and destroys the record; an in-hand consume with units remaining
# materializes the next unit into the same slot and hand.
extends GutTest

const InventoryScript = preload("res://scenes/characters/inventory.gd")
const MedicalItemScript = preload("res://scenes/objects/pickable_items/equipment/consumable/medical/_medical_item.gd")
const CANDLES_STACK := "res://resources/inventory/stackables/candles_stack.tres"
const DAGGER_SCENE := "res://scenes/objects/pickable_items/equipment/melee/dagger/dagger.tscn"
const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"

var _world : Node3D
var _tracked : Array[Node] = []
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
	for node in _tracked:
		if is_instance_valid(node):
			node.free()
	_tracked.clear()


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
	# Headless stub for the equip flow (mirrors test_encumbrance_accounting).
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


## A single-use medical (bandage shape) with the $Sounds/UseComplete nodes
## _on_UseTime_timeout plays on; bare .new() nodes have no scene children.
func _make_single_use(heal : int) -> MedicalItem:
	var item : MedicalItem = MedicalItemScript.new()
	item.max_charges_held = 1
	item.charges_held = 1
	item.heal_amount = heal
	item.item_name = "Bandage"
	item.item_size = GlobalConsts.ItemSize.SIZE_MEDIUM
	var sounds : Node = Node.new()
	sounds.name = "Sounds"
	var use_complete : AudioStreamPlayer = AudioStreamPlayer.new()
	use_complete.name = "UseComplete"
	sounds.add_child(use_complete)
	item.add_child(sounds)
	_tracked.append(item)
	return item


func _make_container() -> MedicalItem:
	var item : MedicalItem = MedicalItemScript.new()
	item.max_charges_held = 10
	item.charges_held = 0
	item.heal_amount = 1
	item.item_name = "Container"
	_tracked.append(item)
	return item


func _spawn_player_with_source(record_count : int, source : MedicalItem) -> Inventory:
	_game_setup()
	var player : Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_world.add_child(player)
	for i in 5:
		await get_tree().physics_frame
	var inv : Inventory = player.get_node("Inventory")
	source.owner_character = player
	inv.hotbar[0] = source
	inv.add_to_stack_record(CANDLES_STACK, DAGGER_SCENE, record_count)
	source.stack_record_id = 0
	inv._recount_encumbrance()
	return inv


func test_refill_consumes_one_record_unit_and_keeps_the_node():
	var source := _make_single_use(4)
	var inv : Inventory = await _spawn_player_with_source(3, source)
	assert_eq(inv.encumbrance, 3.0, "precondition: the medium source represents 3 record units")

	var container := _make_container()
	container.owner_character = source.owner_character

	container._use_reload()

	assert_eq(container.charges_held, 4, "the container absorbed min(space, heal) = 4")
	assert_eq(inv.stack_records[0].count, 2, "the record lost exactly one unit")
	assert_eq(inv.hotbar[0], source, "units remain: the node stays as the representative")
	assert_false(source.is_queued_for_deletion(), "units remain: the node is not freed")
	assert_eq(inv.encumbrance, 2.0, "the remove seam recounted through the representative")


func test_refill_consuming_the_last_unit_clears_the_slot_and_destroys_the_record():
	var source := _make_single_use(4)
	var inv : Inventory = await _spawn_player_with_source(1, source)
	assert_eq(inv.encumbrance, 1.0, "precondition: the last unit is the node itself")

	var container := _make_container()
	container.owner_character = source.owner_character

	container._use_reload()

	assert_eq(container.charges_held, 4, "the container absorbed the charge")
	assert_eq(inv.hotbar[0], null, "the consumed unit's slot is cleared")
	assert_eq(inv.stack_records.size(), 0, "the emptied record is destroyed")
	assert_true(source.is_queued_for_deletion(), "the consumed node is freed")
	assert_eq(inv.encumbrance, 0.0, "the remove seam recounted the unit away")


func test_inhand_consume_materializes_the_next_unit_into_the_same_hand():
	var source := _make_single_use(4)
	var inv : Inventory = await _spawn_player_with_source(3, source)
	inv.current_mainhand_slot = 0
	inv.current_mainhand_equipment = source

	# The T11 consume helper is driven directly: _on_UseTime_timeout's heal
	# prelude reads owner_character.max_health, which the new Player chain
	# (Player -> HumanoidCharacter -> RigidBody3D) does not declare, so the
	# timeout aborts before consumption today. Pre-existing, reported; heal
	# bridging to the State durability model is not S2 scope.
	source._consume_self_through_inventory(inv)

	assert_eq(inv.stack_records[0].count, 2, "the record lost exactly one unit")
	assert_true(source.is_queued_for_deletion(), "the consumed representative is freed")
	var next_unit : EquipmentItem = inv.hotbar[0] as EquipmentItem
	assert_ne(next_unit, source, "a fresh node took the slot")
	assert_eq(next_unit.stack_record_id, 0, "the fresh node is tagged with the record id")
	await get_tree().create_timer(0.7).timeout
	assert_eq(inv.current_mainhand_equipment, next_unit, "the hand re-grips the next unit (owner ruling)")


func test_inhand_consume_of_the_last_unit_unequips_and_destroys_the_record():
	var source := _make_single_use(4)
	var inv : Inventory = await _spawn_player_with_source(1, source)
	inv.current_mainhand_slot = 0
	inv.current_mainhand_equipment = source

	# Driven directly through the helper: see the note in the test above.
	source._consume_self_through_inventory(inv)

	assert_eq(inv.hotbar[0], null, "the slot is cleared")
	assert_eq(inv.current_mainhand_equipment, null, "the hand is empty")
	assert_eq(inv.stack_records.size(), 0, "the emptied record is destroyed")
	assert_true(source.is_queued_for_deletion(), "the consumed node is freed")
