# Tests for the Force Room Purpose debug setting (start game cheat menu,
# group "Generation Settings"). The force must, per floor while set:
# 1. bias room generation so at least one EMPTY room lands inside the forced
#    purpose's required size band (read from its requirements, not hardcoded),
# 2. assign the purpose to EVERY compatible EMPTY room, overriding max_amount,
# and do nothing at all when OFF or when the setting is absent. The forced
# path must also stay deterministic: same seed, same rooms.
extends GutTest

const RoomsStepScript = preload("res://scenes/worlds/world_gen/generation_steps/generate_rooms.gd")
const PurposesStepScript = preload(
		"res://scenes/worlds/world_gen/generation_steps/generate_room_purposes.gd")
const ForceHelper = preload("res://scenes/worlds/world_gen/helper_objects/force_room_purpose.gd")
const StartGameSettingsScript = preload("res://scenes/ui/start_game_settings.gd")
const ProceduralWorldScene = preload(
		"res://scenes/worlds/procedural_world/procedural_world.tscn")

const STATUE := WorldData.OriginalPurpose.STATUE_GALLERY
const TROPHY := WorldData.OriginalPurpose.TROPHY_ROOM
const UP_STAIRS := WorldData.OriginalPurpose.UP_STAIRCASE

var _games: Array = []


func before_each():
	GameManager.game = null
	GameManager.world_gen_rng = null


func after_each():
	for game in _games:
		if is_instance_valid(game):
			game.free()
	_games = []
	GameManager.game = null
	GameManager.world_gen_rng = null


#--- fixtures -------------------------------------------------------------------------------

func _variant_index(variant_name: String) -> int:
	var index: int = StartGameSettingsScript.FORCE_ROOM_PURPOSE_VARIANTS.find(variant_name)
	assert_gte(index, 0, "variant exists in the menu list: " + variant_name)
	return index


func _make_settings(force_variant_index := 0) -> SettingsClass:
	var settings := SettingsClass.new()
	settings.add_int_setting("World Seed", -55555, 55555, 1, 4242)
	settings.set_setting_group("World Seed", "Generation Settings")
	var variants := PackedStringArray(StartGameSettingsScript.FORCE_ROOM_PURPOSE_VARIANTS)
	settings.add_enum_setting(ForceHelper.SETTING_NAME, variants, 0)
	settings.set_setting_group(ForceHelper.SETTING_NAME, "Generation Settings")
	if force_variant_index > 0:
		assert_true(settings.set_setting(ForceHelper.SETTING_NAME, force_variant_index))
	return settings


func _make_game(settings: SettingsClass) -> Game:
	var game := Game.new()
	game.local_settings = settings
	# SettingsClass is a Node: track it too so no fixture nodes orphan.
	if settings and not _games.has(settings):
		_games.append(settings)
	_games.append(game)
	GameManager.game = game
	return game


func _make_size_purpose(purpose_id: String, min_tiles: int, max_tiles: int,
		p_max_amount: int) -> RoomPurpose:
	var purpose := RoomPurpose.new()
	purpose.purpose_id = purpose_id
	purpose.max_amount = p_max_amount
	var min_req := RequirementMinSize.new()
	min_req.min_x_tiles = min_tiles
	min_req.min_y_tiles = min_tiles
	var max_req := RequirementMaxSize.new()
	max_req.max_x_tiles = max_tiles
	max_req.max_y_tiles = max_tiles
	var doorway_req := RequirementDoorways.new()
	doorway_req.min_doorways = 1
	doorway_req.max_doorways = 99
	purpose.requirements = [min_req, max_req, doorway_req]
	return purpose


func _make_statue_purpose(p_max_amount := 2) -> RoomPurpose:
	var purpose := _make_size_purpose("3", 6, 9, p_max_amount)
	purpose.fog_rule = RoomPurpose.FogRule.OFTEN
	purpose.fog_chance = 0.5
	return purpose


func _make_rooms_data() -> WorldData:
	var data := WorldData.new()
	data.resize(24, 24)
	_add_room(data, Rect2(2, 2, 6, 6), WorldData.OriginalPurpose.EMPTY, true)
	_add_room(data, Rect2(10, 2, 4, 4), WorldData.OriginalPurpose.EMPTY, true)
	_add_room(data, Rect2(2, 10, 8, 8), WorldData.OriginalPurpose.EMPTY, false)
	_add_room(data, Rect2(16, 16, 2, 2), UP_STAIRS, true)
	return data


func _add_room(data: WorldData, rect: Rect2, p_type: int, with_doorway: bool) -> void:
	data.fill_room_data(rect, p_type)
	if not with_doorway:
		return
	var cell_index := data.get_cell_index_from_int_position(
			int(rect.position.x), int(rect.position.y))
	var room_data := data.get_cell_meta(
			cell_index, data.CellMetaKeys.META_ROOM_DATA) as RoomData
	room_data.set_doorway_cell(cell_index, WorldData.Direction.NORTH)


func _run_purposes_step(data: WorldData, purposes: Array) -> void:
	var step := PurposesStepScript.new()
	add_child_autofree(step)
	step.purpose_resources = purposes
	step._execute_step(data, {}, 987)


#--- helper unit tests ----------------------------------------------------------------------

func test_forced_name_reader_guards():
	assert_eq(ForceHelper.get_forced_purpose_name(null), "", "no game means no force")
	var game := _make_game(SettingsClass.new())
	assert_eq(ForceHelper.get_forced_purpose_name(game), "",
			"no setting registered means no force")
	var settings := _make_settings(0)
	_games.append(settings)  # the game swaps this one in directly
	game.local_settings = settings
	assert_eq(ForceHelper.get_forced_purpose_name(game), "", "OFF variant means no force")
	settings.set_setting(ForceHelper.SETTING_NAME, _variant_index("STATUE_GALLERY"))
	assert_eq(ForceHelper.get_forced_purpose_name(game), "STATUE_GALLERY")


func test_requirement_readers_use_purpose_data_not_hardcoded_numbers():
	var statue: RoomPurpose = load(
			"res://scenes/worlds/world_gen/helper_objects/room_purposes/statue_gallery.tres")
	assert_eq(ForceHelper.get_required_min_size(statue), Vector2i(6, 6))
	assert_eq(ForceHelper.get_required_max_size(statue), Vector2i(9, 9))
	var crypt: RoomPurpose = load(
			"res://scenes/worlds/world_gen/helper_objects/room_purposes/crypt.tres")
	assert_eq(ForceHelper.get_required_min_size(crypt), Vector2i(3, 3))
	assert_eq(ForceHelper.get_required_max_size(crypt), Vector2i(6, 6))


func test_purpose_display_name_matches_menu_variant():
	var statue: RoomPurpose = load(
			"res://scenes/worlds/world_gen/helper_objects/room_purposes/statue_gallery.tres")
	assert_eq(ForceHelper.get_purpose_display_name(statue), "STATUE_GALLERY")
	assert_true("STATUE_GALLERY" in StartGameSettingsScript.FORCE_ROOM_PURPOSE_VARIANTS,
			"the menu lists the wired statue purpose")


#--- purposes step, force ON ----------------------------------------------------------------

func test_force_assigns_only_compatible_rooms_and_leaves_stairs():
	_make_game(_make_settings(_variant_index("STATUE_GALLERY")))
	var data := _make_rooms_data()
	_run_purposes_step(data, [_make_statue_purpose()])

	var statue_rooms := data.get_rooms_of_type(STATUE)
	assert_eq(statue_rooms.size(), 1, "only the 6x6 room with a doorway fits")
	var forced := statue_rooms[0] as RoomData
	assert_eq(Rect2(forced.rect2), Rect2(2, 2, 6, 6))
	assert_eq(forced.fog_rule, RoomPurpose.FogRule.OFTEN, "fog rule copied onto forced room")
	assert_eq(forced.fog_chance, 0.5, "fog chance copied onto forced room")

	assert_eq(data.get_rooms_of_type(WorldData.OriginalPurpose.EMPTY).size(), 2,
			"small room and doorway-less room stay EMPTY")
	var stairs := data.get_rooms_of_type(UP_STAIRS)
	assert_eq(stairs.size(), 1, "entry stairs untouched")
	assert_eq(Rect2((stairs[0] as RoomData).rect2), Rect2(16, 16, 2, 2))


func test_force_overrides_max_amount_assigning_all_compatible_rooms():
	_make_game(_make_settings(_variant_index("STATUE_GALLERY")))
	var data := WorldData.new()
	data.resize(24, 24)
	_add_room(data, Rect2(2, 2, 6, 6), WorldData.OriginalPurpose.EMPTY, true)
	_add_room(data, Rect2(10, 10, 6, 6), WorldData.OriginalPurpose.EMPTY, true)
	_add_room(data, Rect2(18, 2, 4, 4), WorldData.OriginalPurpose.EMPTY, true)

	_run_purposes_step(data, [_make_statue_purpose(1)])  # max_amount 1

	assert_eq(data.get_rooms_of_type(STATUE).size(), 2,
			"both compatible rooms forced, max_amount overridden")
	assert_eq(data.get_rooms_of_type(WorldData.OriginalPurpose.EMPTY).size(), 1,
			"only the small room stays EMPTY")


#--- purposes step, force OFF ---------------------------------------------------------------

func test_off_keeps_existing_max_amount_truncation():
	_make_game(null)
	var data := WorldData.new()
	data.resize(24, 24)
	_add_room(data, Rect2(2, 2, 6, 6), WorldData.OriginalPurpose.EMPTY, true)
	_add_room(data, Rect2(10, 10, 6, 6), WorldData.OriginalPurpose.EMPTY, true)
	_add_room(data, Rect2(18, 2, 4, 4), WorldData.OriginalPurpose.EMPTY, true)

	_run_purposes_step(data, [_make_statue_purpose(1)])  # max_amount 1

	assert_eq(data.get_rooms_of_type(STATUE).size(), 1,
			"OFF: existing max_amount truncation still limits assignment")
	assert_eq(data.get_rooms_of_type(WorldData.OriginalPurpose.EMPTY).size(), 2,
			"OFF: unchosen rooms stay EMPTY")


#--- rooms step, size guarantee -------------------------------------------------------------

func _run_rooms_step(data: WorldData, settings: SettingsClass, seed_value: int) -> Array:
	_make_game(settings)
	var purposes_step := PurposesStepScript.new()
	purposes_step.purpose_resources = [_make_statue_purpose()]
	add_child_autofree(purposes_step)
	var rooms_step := RoomsStepScript.new()
	add_child_autofree(rooms_step)
	rooms_step.room_size_min = 2  # production values from procedural_world.tscn
	rooms_step.room_size_max = 3
	rooms_step.purpose_step_path = rooms_step.get_path_to(purposes_step)
	rooms_step._execute_step(data, {}, seed_value)
	return data.get_rooms_of_type(WorldData.OriginalPurpose.EMPTY)


func test_rooms_step_guarantees_one_room_in_forced_size_band():
	# Three seeds: the guarantee must hold, not win a seed lottery.
	for seed_value in [12345, 777, 42]:
		var rooms := _run_rooms_step(_make_rooms_data(),
				_make_settings(_variant_index("STATUE_GALLERY")), seed_value)
		var in_band := 0
		for value in rooms:
			var room := value as RoomData
			if room.rect2.size.x >= 6 and room.rect2.size.x <= 9 \
					and room.rect2.size.y >= 6 and room.rect2.size.y <= 9:
				in_band += 1
		assert_gte(in_band, 1,
				"seed %s: at least one EMPTY room meets the forced 6x6..9x9 band" % [seed_value])


func test_rooms_step_deterministic_same_seed_force_on_twice():
	var statue_index := _variant_index("STATUE_GALLERY")
	var rects_a := _run_rooms_step(_make_rooms_data(), _make_settings(statue_index), 777)
	var rects_b := _run_rooms_step(_make_rooms_data(), _make_settings(statue_index), 777)
	assert_eq(rects_a.size(), rects_b.size(), "same seed, same room count")
	for i in rects_a.size():
		assert_eq((rects_a[i] as RoomData).rect2, (rects_b[i] as RoomData).rect2,
				"same seed, same room rects")


func test_rooms_step_deterministic_same_seed_force_off_twice():
	var rooms_a := _run_rooms_step(_make_rooms_data(), _make_settings(0), 777)
	var rooms_b := _run_rooms_step(_make_rooms_data(), _make_settings(0), 777)
	assert_eq(rooms_a.size(), rooms_b.size(), "OFF: same seed, same room count")
	for i in rooms_a.size():
		assert_eq((rooms_a[i] as RoomData).rect2, (rooms_b[i] as RoomData).rect2,
				"OFF: same seed, same room rects")


#--- full pipeline integration --------------------------------------------------------------

func _generate_floor(settings: SettingsClass) -> WorldData:
	_make_game(settings)
	GameManager.world_gen_rng = null  # each run seeds fresh from the World Seed setting
	var world = ProceduralWorldScene.instantiate()
	add_child_autofree(world)
	var manager = world.get_node("GenerationManager")
	return manager.generate(false)


func _room_rects(data: WorldData) -> Array:
	var rects := []
	for room in data.get_all_rooms():
		rects.append((room as RoomData).rect2)
	rects.sort_custom(func(a, b): return a.position.y < b.position.y \
			if a.position.x == b.position.x else a.position.x < b.position.x)
	return rects


func _purpose_type_counts(data: WorldData) -> Dictionary:
	var counts := {}
	for key in WorldData.OriginalPurpose.keys():
		var purpose_type: int = WorldData.OriginalPurpose[key]
		counts[key] = data.get_rooms_of_type(purpose_type).size()
	return counts


func test_full_generation_forces_statue_gallery_on_the_floor():
	var data := _generate_floor(_make_settings(_variant_index("STATUE_GALLERY")))

	var statue_rooms := data.get_rooms_of_type(STATUE)
	assert_gte(statue_rooms.size(), 1, "forced statue gallery present on the floor")
	for value in statue_rooms:
		var room := value as RoomData
		assert_gte(room.rect2.size.x, 6, "statue gallery meets the purpose min size")
		assert_lte(room.rect2.size.x, 9, "statue gallery within the purpose max size")
		assert_gte(room.rect2.size.y, 6, "statue gallery meets the purpose min size")
		assert_lte(room.rect2.size.y, 9, "statue gallery within the purpose max size")

	assert_gte(data.get_rooms_of_type(UP_STAIRS).size(), 1, "entry stairs still present")
	assert_gte(data.get_rooms_of_type(WorldData.OriginalPurpose.DOWN_STAIRCASE).size(), 1,
			"exit stairs still present")


func test_full_generation_forces_trophy_room_on_the_floor():
	var data := _generate_floor(_make_settings(_variant_index("TROPHY_ROOM")))

	var trophy_rooms := data.get_rooms_of_type(TROPHY)
	assert_gte(trophy_rooms.size(), 1, "forced trophy room present on the floor")
	for value in trophy_rooms:
		var room := value as RoomData
		assert_gte(room.rect2.size.x, 6, "trophy room meets the purpose min size")
		assert_lte(room.rect2.size.x, 9, "trophy room within the purpose max size")
		assert_gte(room.rect2.size.y, 6, "trophy room meets the purpose min size")
		assert_lte(room.rect2.size.y, 9, "trophy room within the purpose max size")


func test_full_generation_off_is_deterministic_and_unchanged():
	var counts_a := _purpose_type_counts(_generate_floor(_make_settings(0)))
	var rects_a := _room_rects(_generate_floor(_make_settings(0)))
	var counts_b := _purpose_type_counts(_generate_floor(_make_settings(0)))
	var rects_b := _room_rects(_generate_floor(_make_settings(0)))

	assert_eq(counts_a, counts_b, "OFF: same seed gives identical per-type room counts")
	assert_eq(rects_a, rects_b, "OFF: same seed gives identical room rects")
	assert_gte(counts_a["UP_STAIRCASE"], 1, "OFF run is a sane floor")


func test_menu_variants_match_wired_purposes():
	_make_game(_make_settings(0))
	GameManager.world_gen_rng = null
	var world = ProceduralWorldScene.instantiate()
	add_child_autofree(world)
	var purposes_step = world.get_node("GenerationManager/GenerateRoomPurposes")

	var wired_names := []
	for value in purposes_step.purpose_resources:
		var purpose := value as RoomPurpose
		if purpose:
			wired_names.append(ForceHelper.get_purpose_display_name(purpose))
	wired_names.sort()

	var menu_names := []
	for variant in StartGameSettingsScript.FORCE_ROOM_PURPOSE_VARIANTS:
		if str(variant) != ForceHelper.OFF_VARIANT:
			menu_names.append(str(variant))
	menu_names.sort()

	assert_eq(menu_names, wired_names,
			"menu variants (minus OFF) match the wired purpose resources exactly")
