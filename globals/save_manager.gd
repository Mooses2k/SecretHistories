extends Node

# SaveManager autoload.
# Slot folders user://saves/save_NNN/ (120 slots, 6 per page, 20 pages).
# Format: JSON only:
#   save_data.json : metadata commit marker (written LAST)
#   entities/player.json
#   entities/cultists/*.json   : one per persisted cultist (design 7.2)
#   entities/items/*.json      : dropped items
#   deltas.json : dated typed record log {t, type, floor, target, value}
# Restore = regenerate from World Seed + RNG state, then apply the delta
# overlay. AI capture reads cultist state only; no AI behavior code changes.

const SAVE_ROOT: String = "user://saves/"
const TOTAL_SLOTS: int = 120
const SLOTS_PER_PAGE: int = 6
const TOTAL_PAGES: int = 20
const AUTOSAVE_SLOT: int = 120   # last slot is the floor-transition autosave
const SAVE_VERSION: int = 1

const CULTIST_GROUP: String = "CULTIST"

# Set by begin_load(), consumed by start_loaded_game() and the game hooks.
var pending_load: Dictionary = {}

# Pre-captured screenshot (set before the save screen opens, to avoid
# capturing the picker UI).
var _pending_screenshot: Image = null

var _active_game: Game = null

# Per-floor item identity snapshot taken right after a floor loads (overlay
# applied). At save time, snapshot identities no longer present in the level
# become item_taken records, so the regenerated spawn is suppressed on load.
var _floor_item_snapshots: Dictionary = {}

# The world_gen_rng state captured at the START of the most recent floor
# generation (set by note_rng_state from Game.load_level). A save made on
# floor F must record the stream position floor F's generation started
# from, so Continue regenerates exactly that floor's layout.
var _last_gen_start_rng_state: int = 0

# Per-floor data of the save being loaded, keyed by floor level:
#   "doors"      : {identity_key: record}
#   "taken"      : {identity_key: true}
#   "dropped"    : [item dicts]
#   "cultists"   : {spawn_key: cultist dict}
var _loaded_floor_data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAVE_ROOT)


### Slot paths and manifest reading ------------------------------------------------

func slot_dir(slot_number: int) -> String:
	return SAVE_ROOT + "save_%03d/" % slot_number


func slot_folder_name(slot_number: int) -> String:
	return "save_%03d" % slot_number


# Static sanctioned manifest reader for UI surfaces outside this file.
static func read_slot_manifest(save_dir: String, slot_number: int) -> Dictionary:
	var path: String = save_dir + "save_%03d/save_data.json" % slot_number
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}


func has_slot(slot_number: int) -> bool:
	return FileAccess.file_exists(slot_dir(slot_number) + "save_data.json")


### Screenshot ----------------------------------------------------------------------

func set_pending_screenshot(image: Image) -> void:
	_pending_screenshot = image


func _capture_screenshot(save_path: String) -> void:
	if _pending_screenshot != null:
		var err: int = _pending_screenshot.save_png(save_path + "screenshot.png")
		if err != OK:
			push_warning("[SaveManager] Screenshot save failed (%d)" % err)
		_pending_screenshot = null
		return
	# Headless-safe fallback: skip the screenshot when there is no real render.
	if DisplayServer.get_name() == "headless":
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		push_warning("[SaveManager] No viewport available for screenshot, skipped")
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null:
		push_warning("[SaveManager] Viewport image capture failed, skipped")
		return
	var err2: int = image.save_png(save_path + "screenshot.png")
	if err2 != OK:
		push_warning("[SaveManager] Screenshot save failed (%d)" % err2)


### Saving --------------------------------------------------------------------------

func save_to_slot(slot_number: int) -> bool:
	if slot_number < 1 or slot_number > TOTAL_SLOTS:
		push_error("[SaveManager] Slot %d out of range 1..%d" % [slot_number, TOTAL_SLOTS])
		return false
	if GameManager.game == null or not is_instance_valid(GameManager.game):
		push_error("[SaveManager] No active game to save")
		return false
	var save_path: String = slot_dir(slot_number)
	DirAccess.make_dir_recursive_absolute(save_path + "entities/cultists/")
	DirAccess.make_dir_recursive_absolute(save_path + "entities/items/")

	var game: Game = GameManager.game
	var ok: bool = true

	ok = _write_json(save_path + "entities/player.json",
			JSON.stringify(_capture_player(game), "\t")) and ok
	ok = _write_cultists(save_path, game) and ok
	ok = _write_items(save_path, game) and ok
	ok = _write_json(save_path + "deltas.json",
			JSON.stringify(_build_deltas(game), "\t")) and ok

	_capture_screenshot(save_path)

	# Manifest LAST: commit marker (a crash mid-save leaves no valid manifest).
	ok = _write_json(save_path + "save_data.json",
			JSON.stringify(_build_metadata(game), "\t")) and ok

	if ok:
		print("[SaveManager] Saved slot %d (%s)" % [slot_number, save_path])
	else:
		push_error("[SaveManager] Save to '%s' completed WITH ERRORS" % save_path)
	return ok


func autosave_floor_transition() -> void:
	# One shared entry point for staircase floor changes (design section 4,
	# owner round 2: stairwell streaming transitions hook here later too).
	save_to_slot(AUTOSAVE_SLOT)


func _write_json(path: String, json_str: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] Cannot open '%s' for writing (error %d)" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(json_str)
	f.close()
	return true


func _write_cultists(save_path: String, game: Game) -> bool:
	var ok: bool = true
	var cultists_dir: String = save_path + "entities/cultists/"
	for cultist in _collect_cultists(game):
		var data: Dictionary = _capture_cultist(cultist)
		if data.is_empty():
			continue
		var file_name: String = "cultist_%d_%d.json" % [data["floor"], data["spawn_cell"]]
		ok = _write_json(cultists_dir + file_name, JSON.stringify(data, "\t")) and ok
	return ok


func _write_items(save_path: String, game: Game) -> bool:
	var ok: bool = true
	var items_dir: String = save_path + "entities/items/"
	var index: int = 0
	for floor_level in _iter_levels(game):
		var level: GameWorld = game._loaded_levels[floor_level].get_level_instance()
		if level == null:
			continue
		for item in _collect_pickable_items(level):
			if item.item_state != GlobalConsts.ItemState.DROPPED:
				continue
			var data: Dictionary = {
				"floor": floor_level,
				"scene_path": item.scene_file_path,
				"position": _vec3_to_list(item.global_position),
				"rotation_y": item.global_rotation.y,
			}
			var file_name: String = "item_%d_%03d.json" % [floor_level, index]
			index += 1
			ok = _write_json(items_dir + file_name, JSON.stringify(data, "\t")) and ok
	return ok


func _build_metadata(game: Game) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"world_seed": _get_world_seed(game),
		"floor_level": game.current_floor_level,
		"game_time_sec": Time.get_ticks_msec() / 1000.0,
		"shard_has_spawned": game.shard_has_spawned,
		"quest_flags": {},
		"saved_at": Time.get_datetime_string_from_system(true).replace(":", "").replace("-", ""),
		"screenshot": "screenshot.png",
		# String: the state is int64 and JSON numbers lose int64 precision.
		"world_gen_rng_state": str(_last_gen_start_rng_state),
	}


func _get_world_seed(game: Game) -> int:
	var seed_value: Variant = game.local_settings.get_setting("World Seed")
	return int(seed_value) if seed_value != null else 0


### Capture helpers -----------------------------------------------------------------

func _iter_levels(game: Game) -> Array:
	# All floor levels with a valid GameWorld in memory (current + kept alive).
	var floors: Array = []
	for floor_level in game._loaded_levels:
		var handler: FloorLevelHandler = game._loaded_levels[floor_level]
		if handler != null and is_instance_valid(handler.get_level_instance()):
			floors.append(floor_level)
	return floors


func _collect_pickable_items(level: GameWorld) -> Array:
	return level.find_children("*", "PickableItem", true, false)


func _collect_cultists(game: Game) -> Array:
	# Cultists are tagged with the CULTIST group at spawn time
	# (CharacterSpawnData.ENEMY_GROUP), no frozen-file coupling needed.
	# Group queries only reach in-tree nodes, so scan per level: detached
	# floors kept alive in _loaded_levels are outside the tree.
	var found: Array = []
	for floor_level in _iter_levels(game):
		var level: GameWorld = game._loaded_levels[floor_level].get_level_instance()
		for node in level.find_children("*", "Node", true, false):
			if node.is_in_group(CULTIST_GROUP) and not found.has(node):
				found.append(node)
	return found


func _capture_player(game: Game) -> Dictionary:
	var player: Node = game.player
	var data: Dictionary = {}
	if player == null or not is_instance_valid(player):
		return data
	data["position"] = _vec3_to_list(player.global_position)
	data["rotation_y"] = player.global_rotation.y
	var state: HumanoidCharacterState = player.get_node_or_null("State")
	data["health"] = state.durability if state != null else 0
	data["alive"] = state == null or state.physical_state != HumanoidCharacterState.PhysicalState.DEAD
	var inv: Inventory = player.get_node_or_null("Inventory")
	if inv != null:
		data["inventory"] = _capture_inventory(inv)
	return data


func _capture_inventory(inv: Inventory) -> Dictionary:
	# Shared by the player and the cultists (owner ruling round 2: cultist
	# loadouts are captured too, via the same group-path Inventory node,
	# without touching any character or cultist script).
	var hotbar: Array = []
	for slot in inv.hotbar.size():
		var item: EquipmentItem = inv.hotbar[slot]
		if item != null and is_instance_valid(item):
			var entry: Dictionary = {"path": item.scene_file_path, "slot": slot}
			if "charges_held" in item:
				entry["charges"] = item.charges_held
			hotbar.append(entry)
	var tiny: Dictionary = {}
	for tiny_data in inv.tiny_items:
		var res_path: String = tiny_data.resource_path if tiny_data is Resource else ""
		if res_path != "":
			tiny[res_path] = inv.tiny_items[tiny_data]
	var keys: Dictionary = {}
	for key_id in inv.keychain:
		keys[str(key_id)] = inv.keychain[key_id]
	return {
		"hotbar": hotbar,
		"bulky": inv.bulky_equipment.scene_file_path if inv.bulky_equipment != null and is_instance_valid(inv.bulky_equipment) else "",
		"mainhand_slot": inv.current_mainhand_slot,
		"offhand_slot": inv.current_offhand_slot,
		"tiny_items": tiny,
		"keychain": keys,
	}


func _capture_cultist(cultist: Node) -> Dictionary:
	# Design 7.2 capture: position, rotation_y, health/alive, target ref,
	# spawn-site identity (cell of current position). The BT re-derives
	# everything else. Spawn-site identity is approximated by the cultist's
	# current cell at save time; wandering cultists may then miss their
	# regenerated spawn and are dropped with a logged warning (owner policy).
	var floor_level: int = _floor_of_node(cultist)
	if floor_level == -9999:
		return {}
	var level: GameWorld = GameManager.game._loaded_levels[floor_level].get_level_instance()
	var state: HumanoidCharacterState = cultist.get_node_or_null("State")
	var ai: Node = _find_ai_controller(cultist)
	var data: Dictionary = {
		"floor": floor_level,
		"spawn_cell": _spawn_site_cell(level, cultist.global_position),
		"position": _vec3_to_list(cultist.global_position),
		"rotation_y": cultist.global_rotation.y,
		"health": state.durability if state != null else 0,
		"alive": state != null and state.physical_state != HumanoidCharacterState.PhysicalState.DEAD,
		"target_ref": "player" if (ai != null and ai.ai_state != null and ai.ai_state.target != null and ai.ai_state.target is Player) else "",
		"patrol_anchor": _vec3_to_list(cultist.global_position),
	}
	var inv: Inventory = cultist.get_node_or_null("Inventory")
	if inv != null:
		data["inventory"] = _capture_inventory(inv)
	return data


func _floor_of_node(node: Node) -> int:
	var parent: Node = node.get_parent()
	while parent != null:
		if parent is GameWorld:
			for floor_level in _iter_levels(GameManager.game):
				if GameManager.game._loaded_levels[floor_level].get_level_instance() == parent:
					return floor_level
		parent = parent.get_parent()
	return -9999


func _find_ai_controller(cultist: Node) -> Node:
	var script: GDScript = load("res://scenes/characters/cultist/ai_controller.gd")
	for child in cultist.get_children():
		if child.get_script() == script:
			return child
	return null


func _cell_of(level: GameWorld, global_pos: Vector3) -> int:
	if level.world_data == null:
		return -1
	return level.world_data.get_cell_index_from_local_position(global_pos - level.global_position)


func _spawn_site_cell(level: GameWorld, global_pos: Vector3) -> int:
	# Spawn-site identity: match the cultist back to the world-data spawn it
	# came from (its registered spawn transform), falling back to the cell of
	# its current position. The regenerated spawn cell is the identity on load.
	if level.world_data != null:
		var local_pos: Vector3 = global_pos - level.global_position
		var best_cell: int = -1
		var best_dist: float = 2.0 * WorldData.CELL_SIZE
		for cell_index in level.world_data.get_characters_to_spawn():
			var spawn_data: CharacterSpawnData = level.world_data.get_characters_to_spawn()[cell_index]
			if spawn_data._transforms.is_empty():
				continue
			var spawn_origin: Vector3 = (spawn_data._transforms.front() as Transform3D).origin
			var dist: float = spawn_origin.distance_to(local_pos)
			if dist < best_dist:
				best_dist = dist
				best_cell = cell_index
		if best_cell != -1:
			return best_cell
	return _cell_of(level, global_pos)


func _item_identity(floor_level: int, level: GameWorld, item: Node3D) -> String:
	return "%d|%d|%s" % [floor_level, _cell_of(level, item.global_position), item.scene_file_path]


func _build_deltas(game: Game) -> Dictionary:
	# Record log, not opaque snapshots (design section 7): each deviation
	# from the generated default state is one typed record.
	var now: float = Time.get_ticks_msec() / 1000.0
	var records: Array = []
	for floor_level in _iter_levels(game):
		var level: GameWorld = game._loaded_levels[floor_level].get_level_instance()
		for door in level.find_children("*", "BaseKinematicDoor", true, false):
			var door_record_type: String = ""
			match door.door_state:
				BaseKinematicDoor.DoorState.OPEN, BaseKinematicDoor.DoorState.AUTO_CLOSING:
					door_record_type = "door_opened"
				BaseKinematicDoor.DoorState.STUCK:
					door_record_type = "door_stuck"
				BaseKinematicDoor.DoorState.BROKEN:
					door_record_type = "door_broken"
			if door_record_type == "" and (door.is_locked or door.is_barred):
				# Intact but locked or barred: a deviation from the generated
				# default (unlocked, unbarred) on its own.
				door_record_type = "door_locked"
			if door_record_type != "":
				# Door state value (owner ruling round 2): health, lock/bar
				# flags, door type and lock id travel with every door record.
				# The break impulse direction is not retained on a broken door
				# after the break, so the restore uses a neutral impulse.
				records.append({
					"t": now, "type": door_record_type, "floor": floor_level,
					"target": "door@%d" % _cell_of(level, door.global_position),
					"value": {
						"health": door.health,
						"locked": door.is_locked,
						"barred": door.is_barred,
						"door_type": door.door_type,
						"lock_id": str(door.lock_id),
					},
				})
		# Items recorded by the level-load snapshot but gone from the level
		# at save time were picked up: suppression records so the regenerated
		# spawns are removed on load (the owner's inventory keeps the item).
		var snapshot: Dictionary = _floor_item_snapshots.get(floor_level, {})
		if not snapshot.is_empty():
			var present: Dictionary = {}
			for item in _collect_pickable_items(level):
				present[_item_identity(floor_level, level, item)] = true
			for identity in snapshot:
				if not present.has(identity):
					records.append({
						"t": now, "type": "item_taken", "floor": floor_level,
						"target": identity,
					})
	return {"records": records}


### Loading -------------------------------------------------------------------------

# Prepare a slot for loading. The actual boot happens in start_loaded_game().
func begin_load(slot_number: int) -> Dictionary:
	var save_path: String = slot_dir(slot_number)
	var meta: Dictionary = read_slot_manifest(SAVE_ROOT, slot_number)
	if meta.is_empty():
		push_error("[SaveManager] No valid save in slot %d" % slot_number)
		return {}
	var parsed: Variant = JSON.parse_string(_read_file_or_empty(save_path + "deltas.json"))
	var records: Array = []
	if parsed is Dictionary and parsed.has("records"):
		records = parsed["records"]
	pending_load = {
		"slot": slot_number,
		"meta": meta,
		"records": records,
	}
	return pending_load


func _read_file_or_empty(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


# Boot a Game scene at the saved floor with the saved seed injected
# (the title-menu Continue flow; the picker calls this after begin_load).
func start_loaded_game() -> bool:
	if pending_load.is_empty():
		push_error("[SaveManager] start_loaded_game called without begin_load")
		return false
	var meta: Dictionary = pending_load["meta"]
	var world_seed: int = int(meta.get("world_seed", 0))
	var floor_level: int = int(meta.get("floor_level", Game.HIGHEST_FLOOR_LEVEL))

	var game_scene: PackedScene = load("res://scenes/game.tscn")
	if game_scene == null:
		push_error("[SaveManager] Cannot load game scene")
		return false
	var game: Game = game_scene.instantiate()
	game.current_floor_level = floor_level
	game.shard_has_spawned = bool(meta.get("shard_has_spawned", false))

	# Register the World Seed setting (the same registration the new-game
	# path does in start_game_settings.gd) and inject the saved seed.
	var local_settings: SettingsClass = game.get_node("%LocalSettings")
	local_settings.add_int_setting("World Seed", -55555, 55555, 1, world_seed)
	local_settings.set_setting_group("World Seed", "Generation Settings")
	local_settings.set_setting("World Seed", world_seed)

	# Restore the generation RNG stream state so the saved floor regenerates
	# with exactly the stream position it had at save time (intermediate
	# floors consumed randi() calls between the seed and this floor).
	GameManager.world_gen_rng = RandomNumberGenerator.new()
	GameManager.world_gen_rng.seed = world_seed
	GameManager.world_gen_rng.state = str(meta.get("world_gen_rng_state", "0")).to_int()
	# Later saves on this floor must record this floor's gen-start state.
	_last_gen_start_rng_state = GameManager.world_gen_rng.state

	# Pre-parse the per-floor overlay data while no game is active.
	_loaded_floor_data = _parse_floor_data(pending_load["records"], int(meta.get("floor_level", floor_level)))

	GameManager.is_player_dead = false
	get_tree().root.add_child(game)
	if get_tree().current_scene != null:
		get_tree().call_deferred("unload_current_scene")
	print("[SaveManager] Continuing slot %d: seed %d, floor %d" % [int(pending_load["slot"]), world_seed, floor_level])
	return true


func _parse_floor_data(records: Array, current_floor: int) -> Dictionary:
	# Only the saved floor regenerates at boot; its overlay applies at
	# level_loaded. Other floors' records stay in deltas.json for later use.
	var data: Dictionary = {
		"doors": {}, "taken": {}, "dropped": [], "cultists": {},
	}
	var floor_meta: Dictionary = {}
	for record: Dictionary in records:
		var floor_level: int = int(record.get("floor", current_floor))
		floor_meta[floor_level] = true
		var target: String = str(record.get("target", ""))
		match str(record.get("type", "")):
			"door_opened", "door_stuck", "door_broken":
				if floor_level == current_floor:
					data["doors"][target] = record
			"item_taken":
				if floor_level == current_floor:
					data["taken"][target] = true
			"item_dropped":
				pass
	if floor_meta.has(current_floor) or true:
		pass
	# Dropped items and cultists come from the entity files of the slot.
	var save_path: String = slot_dir(int(pending_load["slot"]))
	var items_dir: String = save_path + "entities/items/"
	if DirAccess.dir_exists_absolute(items_dir):
		var dir: DirAccess = DirAccess.open(items_dir)
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var item: Variant = JSON.parse_string(FileAccess.get_file_as_string(items_dir + file_name))
				if item is Dictionary and int(item.get("floor", current_floor)) == current_floor:
					data["dropped"].append(item)
			file_name = dir.get_next()
		dir.list_dir_end()
	var cultists_dir: String = save_path + "entities/cultists/"
	if DirAccess.dir_exists_absolute(cultists_dir):
		var dir2: DirAccess = DirAccess.open(cultists_dir)
		dir2.list_dir_begin()
		var file_name2: String = dir2.get_next()
		while file_name2 != "":
			if file_name2.ends_with(".json"):
				var cultist: Variant = JSON.parse_string(FileAccess.get_file_as_string(cultists_dir + file_name2))
				if cultist is Dictionary and int(cultist.get("floor", current_floor)) == current_floor:
					data["cultists"]["cultist|%d|%d" % [int(cultist["floor"]), int(cultist["spawn_cell"])]] = cultist
			file_name2 = dir2.get_next()
		dir2.list_dir_end()
	return data


### Game hooks ----------------------------------------------------------------------

# Called by Game.load_level just before a floor generates: captures the
# generation RNG stream position that floor consumes from.
func note_rng_state() -> void:
	if GameManager.world_gen_rng != null:
		_last_gen_start_rng_state = GameManager.world_gen_rng.state


# Called by Game._ready(): wires the one-call hooks for load application and
# floor-transition autosave. No frozen files touched.
func register_game(game: Game) -> void:
	_active_game = game
	if not game.is_connected("level_loaded", _on_game_level_loaded):
		game.connect("level_loaded", _on_game_level_loaded)
	if not game.is_connected("player_spawned", _on_game_player_spawned):
		game.connect("player_spawned", _on_game_player_spawned)


func _on_game_level_loaded(_level: GameWorld) -> void:
	if _active_game == null:
		return
	var floor_level: int = _active_game.current_floor_level
	if _loaded_floor_data.has("floors_done") == false:
		_loaded_floor_data["floors_done"] = {}
	var floor_done: bool = _loaded_floor_data["floors_done"].has(floor_level)
	if pending_load.is_empty():
		# No load in flight: fresh session, capture the item baseline only.
		if not floor_done:
			_loaded_floor_data["floors_done"][floor_level] = true
			_capture_floor_item_snapshot(floor_level)
		return
	if floor_done:
		return
	_loaded_floor_data["floors_done"][floor_level] = true
	_apply_floor_overlay(_active_game, floor_level)
	_capture_floor_item_snapshot(floor_level)


func _capture_floor_item_snapshot(floor_level: int) -> void:
	var level: GameWorld = _active_game.level
	if level == null or not is_instance_valid(level):
		return
	var snapshot: Dictionary = {}
	for item in _collect_pickable_items(level):
		snapshot[_item_identity(floor_level, level, item)] = true
	_floor_item_snapshots[floor_level] = snapshot


func _on_game_player_spawned(player: Node) -> void:
	if _active_game == null or pending_load.is_empty():
		return
	if _loaded_floor_data.has("player_applied"):
		return
	var floor_level: int = int(pending_load["meta"].get("floor_level", -999))
	if _active_game.current_floor_level != floor_level:
		return
	_loaded_floor_data["player_applied"] = true
	_apply_player(player, pending_load["meta"])


func _apply_player(player: Node, meta: Dictionary) -> void:
	var save_path: String = slot_dir(int(pending_load["slot"]))
	var parsed: Variant = JSON.parse_string(_read_file_or_empty(save_path + "entities/player.json"))
	if not (parsed is Dictionary) or (parsed as Dictionary).is_empty():
		print("[SaveManager] No player entity file in save, keeping generated spawn")
		return
	var data: Dictionary = parsed
	player.global_position = _list_to_vec3(data.get("position", [0, 0, 0]))
	player.global_rotation.y = float(data.get("rotation_y", 0.0))
	var state: HumanoidCharacterState = player.get_node_or_null("State")
	if state != null:
		state.set_durability(int(data.get("health", state.durability)))
	var inv: Inventory = player.get_node_or_null("Inventory")
	if inv != null and data.has("inventory"):
		_apply_inventory(inv, data["inventory"])
	print("[SaveManager] Player restored at %s (slot meta floor %s)" % [player.global_position, str(meta.get("floor_level"))])


func _apply_inventory(inv: Inventory, data: Dictionary) -> void:
	# Bulky equipment first (the ShardOfTheComet win condition rides here).
	var bulky_path: String = str(data.get("bulky", ""))
	if bulky_path != "":
		_spawn_into_inventory(inv, bulky_path, -1)
	for entry: Variant in data.get("hotbar", []):
		if entry is Dictionary:
			_spawn_into_inventory(inv, str(entry.get("path", "")), -1, int(entry.get("charges", -1)))
	for res_path: String in data.get("tiny_items", {}):
		var tiny_res: Resource = load(res_path)
		if tiny_res is TinyItemData:
			inv.insert_tiny_item(tiny_res, int(data["tiny_items"][res_path]))
	for key_id: String in data.get("keychain", {}):
		inv.keychain[int(key_id)] = int(data["keychain"][key_id])
	inv.set_mainhand_slot(int(data.get("mainhand_slot", 0)))
	inv.set_offhand_slot(int(data.get("offhand_slot", Inventory.hands_free_slot)))


func _spawn_into_inventory(inv: Inventory, scene_path: String, _slot: int, charges: int = -1) -> void:
	if scene_path == "":
		return
	var scene: PackedScene = load(scene_path)
	if scene == null:
		push_warning("[SaveManager] Cannot load item scene '%s', skipped" % scene_path)
		return
	var item: Node = scene.instantiate()
	if item is EquipmentItem and charges >= 0 and "charges_held" in item:
		item.charges_held = charges
	# add_item requires the DROPPED state; fresh instances already are.
	inv.add_item(item)


func _apply_floor_overlay(game: Game, floor_level: int) -> void:
	if _loaded_floor_data.has("doors") == false:
		return
	var level: GameWorld = game.level
	if level == null or not is_instance_valid(level):
		return

	# 1. Suppress items that the delta log records as taken/owned.
	for item in _collect_pickable_items(level):
		var identity: String = _item_identity(floor_level, level, item)
		if _loaded_floor_data["taken"].has(identity):
			print("[SaveManager] Suppressing re-spawned taken item: %s" % identity)
			item.queue_free()

	# 2. Re-spawn dropped items.
	var level_parent: Node = level.get_parent()
	for item_data: Dictionary in _loaded_floor_data.get("dropped", []):
		var scene: PackedScene = load(str(item_data.get("scene_path", "")))
		if scene == null:
			push_warning("[SaveManager] Cannot load dropped item scene '%s'" % str(item_data.get("scene_path")))
			continue
		var item: Node = scene.instantiate()
		level_parent.add_child(item)
		if item is Node3D:
			item.global_position = _list_to_vec3(item_data.get("position", [0, 0, 0]))
			item.global_rotation.y = float(item_data.get("rotation_y", 0.0))

	# 3. Doors: apply the record state (default CLOSED needs no record).
	for door in level.find_children("*", "BaseKinematicDoor", true, false):
		var record: Dictionary = _loaded_floor_data["doors"].get("door@%d" % _cell_of(level, door.global_position), {})
		if record.is_empty():
			continue
		var value: Dictionary = record.get("value", {}) if record.get("value", {}) is Dictionary else {}
		# Restore flags first, the state below may interact with them.
		if not value.is_empty():
			door.is_locked = bool(value.get("locked", false))
			door.is_barred = bool(value.get("barred", false))
			door.lock_id = int(value.get("lock_id", 0))
			door.health = float(value.get("health", door.health))
		match str(record.get("type", "")):
			"door_opened":
				door.door_state = BaseKinematicDoor.DoorState.OPEN
				door.door_should_move = true
			"door_stuck":
				door.door_state = BaseKinematicDoor.DoorState.STUCK
			"door_broken":
				# Owner ruling round 2: broken doors restore broken, through
				# the door's own public break path. The break impulse direction
				# is not retained on the door after the break, so the restore
				# uses a neutral zero impulse; the pieces rest where they land.
				door.break_door(0, GlobalConsts.AttackTypes.BLUDGEONING, Vector3.ZERO, door.global_position)
				print("[SaveManager] Broken door restored broken via break_door: %s" % door.name)
			"door_locked":
				# Intact locked/barred door: flags already applied above.
				pass

	# 4. Cultists: match by spawn-site identity (design 7.2), drop-with-
	# logged-warning on mismatch (owner round 2 policy).
	var cultist_data: Dictionary = _loaded_floor_data.get("cultists", {})
	for node in level.get_tree().get_nodes_in_group(CULTIST_GROUP):
		if not is_instance_valid(node) or not level.is_ancestor_of(node):
			continue
		var spawn_key: String = "cultist|%d|%d" % [floor_level, _cell_of(level, node.global_position)]
		var saved: Dictionary = cultist_data.get(spawn_key, {})
		if saved.is_empty():
			push_warning("[SaveManager] Cultist drop: no saved spawn-site match for %s (%s), BT keeps generated state" % [node.name, spawn_key])
			continue
		node.global_position = _list_to_vec3(saved.get("position", [0, 0, 0]))
		node.global_rotation.y = float(saved.get("rotation_y", 0.0))
		var state: HumanoidCharacterState = node.get_node_or_null("State")
		if state != null:
			state.set_durability(int(saved.get("health", state.durability)))
			if not bool(saved.get("alive", true)):
				state.set_durability(0)
		var ai: Node = _find_ai_controller(node)
		if ai != null and ai.ai_state != null and str(saved.get("target_ref", "")) == "player" and game.player != null:
			ai.ai_state.target = game.player
		# Owner ruling round 2: cultist loadouts restore too. The regenerated
		# cultist carries a fresh random loadout; it is cleared and replaced
		# with the saved one. All through public Inventory data and the same
		# add_item spawn path used for re-dropped items; no character or
		# cultist script is touched.
		if saved.has("inventory") and saved["inventory"] is Dictionary:
			_apply_cultist_inventory(node, saved["inventory"])
	print("[SaveManager] Floor overlay applied for floor %d (doors %d, taken %d, dropped %d, cultists %d)" % [
			floor_level, _loaded_floor_data["doors"].size(),
			_loaded_floor_data["taken"].size(),
			(_loaded_floor_data.get("dropped", []) as Array).size(),
			cultist_data.size()])


### Small helpers -------------------------------------------------------------------

# Replace a freshly generated cultist loadout with the saved one. The fresh
# loadout nodes are freed (they are plain PickableItem nodes the cultist was
# spawned with), then the saved items are spawned through the same add_item
# path the player's inventory restore uses.
func _apply_cultist_inventory(cultist: Node, data: Dictionary) -> void:
	var inv: Inventory = cultist.get_node_or_null("Inventory")
	if inv == null:
		push_warning("[SaveManager] Cultist has no Inventory node, loadout not restored")
		return
	# Clear the fresh loadout: hotbar nodes, held items, tiny stacks, keys.
	for slot in inv.hotbar.size():
		var item: EquipmentItem = inv.hotbar[slot]
		if item != null and is_instance_valid(item):
			item.queue_free()
		inv.hotbar[slot] = null
	for held in [inv.current_mainhand_equipment, inv.current_offhand_equipment]:
		if held != null and is_instance_valid(held) and not held.is_queued_for_deletion():
			held.queue_free()
	inv.current_mainhand_equipment = null
	inv.current_offhand_equipment = null
	inv.current_mainhand_slot = 0
	inv.current_offhand_slot = Inventory.hands_free_slot
	inv.tiny_items.clear()
	inv.keychain.clear()
	if inv.bulky_equipment != null and is_instance_valid(inv.bulky_equipment) and not inv.bulky_equipment.is_queued_for_deletion():
		inv.bulky_equipment.queue_free()
	inv.bulky_equipment = null
	# Spawn the saved loadout through the shared restore path.
	_apply_inventory(inv, data)


func _vec3_to_list(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _list_to_vec3(list: Variant) -> Vector3:
	if list is Array and (list as Array).size() == 3:
		return Vector3(list[0], list[1], list[2])
	return Vector3.ZERO


func delete_save(folder_name: String) -> bool:
	var folder_path: String = SAVE_ROOT + folder_name + "/"
	if not DirAccess.dir_exists_absolute(folder_path):
		return true
	var removed: bool = _remove_dir_recursive(folder_path)
	if removed:
		print("[SaveManager] Deleted save '%s'" % folder_name)
	else:
		push_error("[SaveManager] Failed to delete save '%s'" % folder_name)
	return removed


func _remove_dir_recursive(path: String) -> bool:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = path + entry
		if dir.current_is_dir():
			if not _remove_dir_recursive(full + "/"):
				return false
		else:
			if dir.remove(entry) != OK:
				return false
		entry = dir.get_next()
	dir.list_dir_end()
	# The directory itself is removed once it is empty (absolute path,
	# no trailing slash, per DirAccess semantics).
	return DirAccess.remove_absolute(path.rstrip("/")) == OK
