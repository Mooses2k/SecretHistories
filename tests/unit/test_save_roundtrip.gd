# Save roundtrip through the real SaveManager path, headless (GUT batch C).
# Scope and provenance:
# - Real path driven: save_to_slot() writes the real slot files under
#   user://saves/save_119/, then begin_load(), _parse_floor_data(),
#   _apply_player() and _apply_floor_overlay() read them back and restore.
#   start_loaded_game() itself is NOT driven: it boots scenes/game.tscn and
#   unloads the current scene, which would tear down the GUT runner. The
#   sequence here is the production sequence minus the scene boot; everything
#   before it (manifest + deltas parsing, player and floor overlay restore)
#   runs through the real autoload functions.
# - World state: player with a non-stack equipped loadout (mace + hatchet),
#   one stack of tiny items (spyglass x3), a keychain entry, floor level -3,
#   and one door with non-default open/damage/locked state. The door save
#   path IS reachable headless (deltas capture and the floor overlay are
#   pure state application over the real door scene), so doors stay in scope.
# - Restore semantics pinned are the real ones: hotbar items re-place through
#   the live add_item path (the multiset of item scenes is asserted, not
#   per-slot placement), mainhand/offhand slot indices, tiny item counts,
#   keychain, player position/rotation/health, and the door's state, flags
#   and health. The load phase regenerates a fresh default door, exactly as
#   the seeded world generation would, before the overlay applies the record.
# - Stack counts roundtrip through the Tier C format (T12/T13): the dagger
#   stack is saved with its record count and restored as one representative
#   with a fresh count-2 record; known_tiny_items roundtrip too (T12).
# - Encumbrance is recomputed at load (owner decision 5), never persisted:
#   the load-side value is asserted against the restored inventory.
extends GutTest


const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const MACE_SCENE := "res://scenes/objects/pickable_items/equipment/melee/mace/mace.tscn"
const HATCHET_SCENE := "res://scenes/objects/pickable_items/equipment/melee/hatchet/hatchet.tscn"
const DAGGER_SCENE := "res://scenes/objects/pickable_items/equipment/melee/dagger/dagger.tscn"
const SPYGLASS_RESOURCE := "res://resources/tiny_items/spyglass.tres"
const DOOR_SCENE := preload("res://scenes/objects/large_objects/doors/base_kinematic_door.tscn")

const SAVE_SLOT := 119
const FLOOR_LEVEL := -3
const WORLD_SEED := 4242
const DOOR_LOCAL_POS := Vector3(2.25, 0.0, 2.25)
const DOOR_SAVED_HEALTH := 42.5
const DOOR_SAVED_LOCK_ID := 7
const PLAYER_SAVED_POS := Vector3(2.0, 1.0, 2.0)
const PLAYER_SAVED_ROTATION_Y := 0.5
const PLAYER_SAVED_HEALTH := 63
const EQUIP_SETTLE_SEC := 0.7

var _saved_game : Game
var _saved_active_game : Game
var _saved_pending_load : Dictionary
var _saved_floor_data : Dictionary
var _saved_snapshots : Dictionary
var _world : Node3D
var _game_a : Game
var _game_b : Game
var _level_a : GameWorld
var _level_b : GameWorld
var _player_b : RigidBody3D
var _stub_nodes : Array[Node] = []


func before_each() -> void:
	# Snapshot the SaveManager autoload state so the test leaves no residue.
	_saved_active_game = SaveManager._active_game
	_saved_pending_load = SaveManager.pending_load
	_saved_floor_data = SaveManager._loaded_floor_data
	_saved_snapshots = SaveManager._floor_item_snapshots
	SaveManager._active_game = null
	SaveManager.pending_load = {}
	SaveManager._loaded_floor_data = {}
	SaveManager._floor_item_snapshots = {}
	SaveManager.delete_save(SaveManager.slot_folder_name(SAVE_SLOT))

	_saved_game = GameManager.game
	_world = Node3D.new()
	_world.name = "TestWorld"
	add_child(_world)


func after_each() -> void:
	SaveManager.delete_save(SaveManager.slot_folder_name(SAVE_SLOT))
	SaveManager.pending_load = {}
	SaveManager._loaded_floor_data = {}
	SaveManager._floor_item_snapshots = {}
	SaveManager._active_game = _saved_active_game
	# The restore path spawns hotbar items unparented (add_item removes them
	# from the world only when they are in it); free those before the tree
	# teardown so the test leaves no orphans.
	if is_instance_valid(_player_b):
		var inv : Inventory = _player_b.get_node_or_null("Inventory")
		if inv != null:
			for slot in inv.hotbar.size():
				var item_value : Variant = inv.hotbar[slot]
				if item_value != null and is_instance_valid(item_value) \
						and (item_value as Node).get_parent() == null:
					(item_value as Node).free()
	if is_instance_valid(_game_a):
		_game_a.free()
	if is_instance_valid(_game_b):
		_game_b.free()
	_world.free()
	for node in _stub_nodes:
		if is_instance_valid(node):
			node.free()
	_stub_nodes.clear()
	GameManager.game = _saved_game


func _track(node : Node) -> void:
	_stub_nodes.append(node)


func _make_world_data() -> WorldData:
	var world_data : WorldData = WorldData.new()
	world_data.cell_type.resize(world_data.cell_count)
	return world_data


# Both phases build the level in the tree with the scene children
# GameWorld._ready expects (GenerationManager typed, the rest looked up by
# name): the door and item captures read global transforms, which need the
# tree, and _apply_floor_overlay queries the tree for cultists.
func _make_level(world_data : WorldData) -> GameWorld:
	var level : GameWorld = GameWorld.new()
	level.world_data = world_data
	var gen_manager : GenerationManager = GenerationManager.new()
	gen_manager.name = "GenerationManager"
	level.add_child(gen_manager)
	var gridmaps : Node = Node.new()
	gridmaps.name = "Gridmaps"
	level.add_child(gridmaps)
	var navigation : Node = Node.new()
	navigation.name = "Navigation"
	level.add_child(navigation)
	var spawner : CharacterSpawner = CharacterSpawner.new()
	spawner.name = "CharacterSpawner"
	level.add_child(spawner)
	_world.add_child(level)
	return level


func _make_stub_game(level : GameWorld) -> Game:
	# Same headless stub shape as test_throw_blueprint_basis.gd: keeps the
	# player's per-frame handlers error-free.
	var game : Game = Game.new()
	game.level = level
	game.current_floor_level = FLOOR_LEVEL
	var ui : GameUI = GameUI.new()
	var hud : HUD = HUD.new()
	var indicators : Array[TextureRect] = [
		TextureRect.new(), TextureRect.new(), TextureRect.new(),
	]
	hud.indicators = indicators
	hud.add_child(indicators[0])
	hud.add_child(indicators[1])
	hud.add_child(indicators[2])
	ui.hud_root = hud
	game.ui_root = ui
	_track(ui)
	_track(hud)
	return game


func _make_door(level : GameWorld) -> BaseKinematicDoor:
	var door : BaseKinematicDoor = DOOR_SCENE.instantiate()
	door.position = DOOR_LOCAL_POS
	door.door_stuck_on_close_probability = 0.0
	level.add_child(door)
	return door


func test_save_roundtrip_restores_inventory_floor_and_door_state() -> void:
	# ---- save phase: build the representative world state ----
	var world_data : WorldData = _make_world_data()
	_level_a = _make_level(world_data)
	_game_a = _make_stub_game(_level_a)
	var settings : SettingsClass = SettingsClass.new()
	settings.add_int_setting("World Seed", -55555, 55555, 1, WORLD_SEED)
	_game_a.local_settings = settings
	_game_a.shard_has_spawned = true
	_game_a._loaded_levels = {FLOOR_LEVEL: FloorLevelHandler.new(_level_a, FLOOR_LEVEL)}
	_track(settings)

	var player_a : RigidBody3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player_a.freeze = true
	_world.add_child(player_a)
	_game_a.player = player_a

	var inv_a : Inventory = player_a.get_node("Inventory")
	var mace_a : EquipmentItem = add_child_autofree((load(MACE_SCENE) as PackedScene).instantiate()) as EquipmentItem
	var hatchet_a : EquipmentItem = add_child_autofree((load(HATCHET_SCENE) as PackedScene).instantiate()) as EquipmentItem
	inv_a.hotbar[0] = mace_a
	inv_a.hotbar[1] = hatchet_a
	# A medium (mace) and a small (hatchet) pickup's worth; the save stores
	# no encumbrance value and the load recomputes it (owner decision 5),
	# asserted on the load side.
	inv_a.encumbrance = 2.0
	# A real dagger stack through the live pickup flow: the first places and
	# tags, the second merges, one record holds 2 units (T1/T2/T3).
	var dagger_a : EquipmentItem = add_child_autofree((load(DAGGER_SCENE) as PackedScene).instantiate()) as EquipmentItem
	assert_true(inv_a.add_item(dagger_a), "precondition: the first dagger is picked up")
	var dagger_b : EquipmentItem = add_child_autofree((load(DAGGER_SCENE) as PackedScene).instantiate()) as EquipmentItem
	assert_true(inv_a.add_item(dagger_b), "precondition: the second dagger merges")
	assert_eq(inv_a.stack_records[0].count, 2, "precondition: the dagger record holds 2 units")
	var spyglass : TinyItemData = load(SPYGLASS_RESOURCE)
	inv_a.insert_tiny_item(spyglass, 3)
	inv_a.keychain[DOOR_SAVED_LOCK_ID] = 2

	var door_a : BaseKinematicDoor = _make_door(_level_a)
	# Non-default open/damage state: open, damaged, locked, with a lock id.
	door_a.health = DOOR_SAVED_HEALTH
	door_a.is_locked = true
	door_a.lock_id = DOOR_SAVED_LOCK_ID
	door_a.door_state = BaseKinematicDoor.DoorState.OPEN
	player_a.global_position = PLAYER_SAVED_POS
	player_a.global_rotation.y = PLAYER_SAVED_ROTATION_Y
	player_a.get_node("State").set_durability(PLAYER_SAVED_HEALTH)

	# ---- save through the real path ----
	assert_true(SaveManager.save_to_slot(SAVE_SLOT), "save_to_slot writes the slot")
	assert_true(SaveManager.has_slot(SAVE_SLOT), "the saved slot has a manifest")

	# ---- reset state: every save-phase node is dropped (the Continue flow
	# regenerates from the seed; here the load side is built fresh below) ----
	player_a.free()
	_level_a.free()
	_level_a = null

	# ---- load phase: regenerate fresh, apply the real load path ----
	_level_b = _make_level(world_data)
	_game_b = _make_stub_game(_level_b)
	# The regenerated floor carries a default door, as generation would.
	_make_door(_level_b)

	var pending : Dictionary = SaveManager.begin_load(SAVE_SLOT)
	assert_false(pending.is_empty(), "begin_load reads the saved manifest")
	assert_eq(int(pending["meta"]["floor_level"]), FLOOR_LEVEL, "floor level roundtrips through the manifest")
	assert_eq(int(pending["meta"]["world_seed"]), WORLD_SEED, "world seed roundtrips through the manifest")
	assert_true(bool(pending["meta"]["shard_has_spawned"]), "shard flag roundtrips through the manifest")
	var record_types : Array = []
	for record : Variant in pending["records"]:
		record_types.append(str((record as Dictionary)["type"]))
	assert_has(record_types, "door_opened", "the open door produced a door_opened delta record")

	SaveManager._loaded_floor_data = SaveManager._parse_floor_data(pending["records"], FLOOR_LEVEL)

	_player_b = (load(PLAYER_SCENE) as PackedScene).instantiate() as RigidBody3D
	_player_b.freeze = true
	_world.add_child(_player_b)
	_game_b.player = _player_b
	SaveManager._apply_player(_player_b, pending["meta"])
	assert_almost_eq(_player_b.global_position, PLAYER_SAVED_POS, Vector3.ONE * 0.001, "player position roundtrips")
	assert_almost_eq(_player_b.global_rotation.y, PLAYER_SAVED_ROTATION_Y, 0.001, "player rotation roundtrips")
	assert_eq(_player_b.get_node("State").durability, PLAYER_SAVED_HEALTH, "player durability roundtrips")

	var door_b : BaseKinematicDoor = _door_of(_game_b.level)
	SaveManager._apply_floor_overlay(_game_b, FLOOR_LEVEL)
	assert_eq(door_b.door_state, BaseKinematicDoor.DoorState.OPEN, "door open state roundtrips")
	assert_almost_eq(door_b.health, DOOR_SAVED_HEALTH, 0.001, "door damage state roundtrips")
	assert_true(door_b.is_locked, "door locked flag roundtrips")
	assert_eq(door_b.lock_id, DOOR_SAVED_LOCK_ID, "door lock id roundtrips")

	var inv_b : Inventory = _player_b.get_node("Inventory")
	var restored_paths : Array = []
	var restored_dagger : EquipmentItem = null
	for slot in inv_b.hotbar.size():
		var item_value : Variant = inv_b.hotbar[slot]
		if item_value != null:
			var restored_item : EquipmentItem = item_value as EquipmentItem
			restored_paths.append(restored_item.scene_file_path)
			if restored_item.scene_file_path == DAGGER_SCENE:
				restored_dagger = restored_item
	restored_paths.sort()
	var expected_paths : Array = [DAGGER_SCENE, HATCHET_SCENE, MACE_SCENE]
	expected_paths.sort()
	assert_eq(restored_paths, expected_paths, "the loadout roundtrips, stack included")
	assert_not_null(restored_dagger, "the dagger representative roundtrips")
	var restored_record : StackableStackRecord = inv_b.get_stack_record(restored_dagger.stack_record_id)
	assert_eq(restored_record.count, 2, "T13: the stack count roundtrips onto a fresh record")
	assert_eq(String(restored_record.type_id), "res://resources/inventory/stackables/daggers_stack.tres",
		"T13: the restored record keeps the stack type")
	assert_eq(inv_b.stack_records.size(), 1, "exactly one record for the one stack")
	assert_eq(inv_b.encumbrance, 1.0,
		"T13: encumbrance is recomputed at load (medium mace + small hatchet + a 0-weight dagger stack), never persisted")
	assert_eq(inv_b.tiny_item_amount(spyglass), 3, "the tiny item stack count roundtrips")
	assert_eq(inv_b.tiny_items.size(), 1, "only the saved tiny item type is present")
	assert_true(inv_b.known_tiny_items.has(spyglass), "T12: the awareness set roundtrips")
	assert_eq(inv_b.keychain, {DOOR_SAVED_LOCK_ID: 2}, "the keychain roundtrips")
	assert_eq(inv_b.current_mainhand_slot, 0, "mainhand slot index roundtrips")
	assert_eq(inv_b.current_offhand_slot, Inventory.hands_free_slot, "offhand slot index roundtrips")

	# The restore path's equip coroutines settle on the 0.5 s timer; after
	# that the item at the restored mainhand slot is the equipped one.
	await get_tree().create_timer(EQUIP_SETTLE_SEC).timeout
	var mainhand : EquipmentItem = inv_b.current_mainhand_equipment
	assert_true(is_instance_valid(mainhand), "the restored mainhand equip settled")
	if is_instance_valid(mainhand):
		assert_eq(mainhand.scene_file_path, MACE_SCENE, "the restored mainhand slot's item is the equipped one")


func _door_of(level : GameWorld) -> BaseKinematicDoor:
	var found : Array = level.find_children("*", "BaseKinematicDoor", true, false)
	assert_eq(found.size(), 1, "exactly one door on the regenerated floor")
	if found.is_empty():
		return null
	return found[0] as BaseKinematicDoor
