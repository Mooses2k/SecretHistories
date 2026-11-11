# Tests for the per-room FogVolume placement in generate_room_fog.gd.
# The playtest rejected per-cell billboard fog (a fog pocket on every cell);
# the fog step must place ONE room-filling FogVolume per fogged room, never
# one spawn per cell, and the volume must stay inside the room interior plus
# a small margin buried in the walls, so it cannot bleed into neighbours.
# Also pins the wiring the whole design hinges on: the fog effect scenes are
# FogVolume roots with FogMaterial, the game environment has volumetric fog
# enabled with zero ambient density (so only FogVolumes show fog), and the
# fog-rework room-type rules: fountain and statue purposes carry the OFTEN
# fog rule, the other shipped purposes keep the small SOMETIMES default.
extends GutTest

const FogStepScript = preload("res://scenes/worlds/world_gen/generation_steps/populate_room/generate_room_fog.gd")

const ROOM_A_RECT := Rect2(2, 2, 4, 3)  # 4x3 cells, gets fog
const ROOM_B_RECT := Rect2(8, 2, 3, 3)  # 3x3 cells, stays clean
const FOG_SCENE := "res://scenes/effects/fog_room_volume_thick.tscn"
const FOG_SCENE_PREFIX := "res://scenes/effects/fog_room_volume"

var data : WorldData


func before_each():
	# Headless: no game, so nothing else can interfere with the spawn dicts.
	GameManager.game = null
	data = WorldData.new()
	data.resize(16, 16)
	data.fill_room_data(ROOM_A_RECT, WorldData.OriginalPurpose.CRYPT)
	data.fill_room_data(ROOM_B_RECT, WorldData.OriginalPurpose.FOUNTAIN)


func _room_a() -> RoomData:
	return data.get_rooms_of_type(WorldData.OriginalPurpose.CRYPT)[0]


func _run_fog_step(room_paths := {}, weather_scene_path := "") -> void:
	var step = FogStepScript.new()
	add_child_autofree(step)
	step.room_paths = room_paths
	step.weather_scene_path = weather_scene_path
	step._execute_step(data, {}, 12345)


func _fog_spawn_cells() -> Array:
	var cells := []
	for cell_index in data.get_objects_to_spawn():
		var spawn_data = data.get_objects_to_spawn()[cell_index]
		if str(spawn_data.scene_path).begins_with(FOG_SCENE_PREFIX):
			cells.append(cell_index)
	return cells


func test_one_volume_per_fogged_room_never_one_per_cell():
	_run_fog_step({_room_a(): FOG_SCENE})
	var fog_cells := _fog_spawn_cells()
	assert_eq(fog_cells.size(), 1, "exactly one fog spawn for the fogged room")
	assert_eq(data.get_objects_to_spawn().size(), 1, "no other spawn data placed")
	assert_true(fog_cells[0] in _room_a().cell_indexes, "anchor cell belongs to the fogged room")


func test_clean_rooms_get_nothing():
	_run_fog_step({_room_a(): FOG_SCENE})
	for cell_index in data.get_objects_to_spawn():
		var spawn_data = data.get_objects_to_spawn()[cell_index]
		assert_false(
			str(spawn_data.scene_path).begins_with(FOG_SCENE_PREFIX) \
				and not (cell_index in _room_a().cell_indexes),
			"clean room has no fog spawn")


func test_special_all_fog_floor_covers_every_real_room():
	_run_fog_step({}, FOG_SCENE)
	var fog_cells := _fog_spawn_cells()
	assert_eq(fog_cells.size(), 2, "one fog spawn per non-empty room")
	var covered_rooms := 0
	for room in data.get_all_rooms():
		var room_has_fog := false
		for cell_index in fog_cells:
			if cell_index in room.cell_indexes:
				room_has_fog = true
		if room_has_fog:
			covered_rooms += 1
	assert_eq(covered_rooms, 2, "every real room is covered")


func test_empty_type_rooms_are_skipped():
	var empty_rect := Rect2(2, 8, 2, 2)
	data.fill_room_data(empty_rect, WorldData.OriginalPurpose.EMPTY)
	_run_fog_step({}, FOG_SCENE)
	for cell_index in _fog_spawn_cells():
		var pos = data.get_int_position_from_cell_index(cell_index)
		var inside_empty_room: bool = pos[0] >= empty_rect.position.x \
			and pos[0] < empty_rect.end.x and pos[1] >= empty_rect.position.y \
			and pos[1] < empty_rect.end.y
		assert_false(inside_empty_room, "empty-type room got no fog spawn")


func test_volume_bounds_inside_room_interior_with_buried_margin_only():
	_run_fog_step({_room_a(): FOG_SCENE})
	var fog_cells := _fog_spawn_cells()
	assert_eq(fog_cells.size(), 1)
	var spawn_data = data.get_objects_to_spawn()[fog_cells[0]]
	var props: Dictionary = spawn_data._custom_properties[0]
	assert_true(props.has("position"), "volume center custom property present")
	assert_true(props.has("size"), "volume size custom property present")
	var center: Vector3 = props["position"]
	var size: Vector3 = props["size"]

	# Room interior in world space.
	var room_min := Vector2(
		ROOM_A_RECT.position.x * WorldData.CELL_SIZE,
		ROOM_A_RECT.position.y * WorldData.CELL_SIZE)
	var room_max := Vector2(
		ROOM_A_RECT.end.x * WorldData.CELL_SIZE,
		ROOM_A_RECT.end.y * WorldData.CELL_SIZE)
	var margin := FogStepScript.HORIZONTAL_WALL_MARGIN

	# The volume may exceed the room only by the buried wall margin, never
	# enough to reach a neighbour through the 0.15 m walls.
	assert_gte(center.x - size.x * 0.5, room_min.x - margin - 0.01, "volume west edge inside the wall")
	assert_lte(center.x + size.x * 0.5, room_max.x + margin + 0.01, "volume east edge inside the wall")
	assert_gte(center.z - size.z * 0.5, room_min.y - margin - 0.01, "volume north edge inside the wall")
	assert_lte(center.z + size.z * 0.5, room_max.y + margin + 0.01, "volume south edge inside the wall")

	# The volume reaches the full room interior: no fog-free zone mid-room.
	assert_lte(center.x - size.x * 0.5, room_min.x + 0.01, "volume covers the room's west edge")
	assert_gte(center.x + size.x * 0.5, room_max.x - 0.01, "volume covers the room's east edge")
	assert_lte(center.z - size.z * 0.5, room_min.y + 0.01, "volume covers the room's north edge")
	assert_gte(center.z + size.z * 0.5, room_max.y - 0.01, "volume covers the room's south edge")

	# Vertical span: from below the floor slab to above the ceiling line.
	assert_lte(center.y - size.y * 0.5, -FogStepScript.VERTICAL_SLAB_MARGIN + 0.01, "volume starts under the floor")
	assert_gte(center.y + size.y * 0.5, WorldData.WALL_SIZE + FogStepScript.VERTICAL_SLAB_MARGIN - 0.01, "volume ends over the ceiling line")


func test_volume_center_is_room_center_at_mid_height():
	_run_fog_step({_room_a(): FOG_SCENE})
	var spawn_data = data.get_objects_to_spawn()[_fog_spawn_cells()[0]]
	var center: Vector3 = spawn_data._custom_properties[0]["position"]
	var expected := Vector3(
		ROOM_A_RECT.get_center().x * WorldData.CELL_SIZE,
		WorldData.WALL_SIZE * 0.5,
		ROOM_A_RECT.get_center().y * WorldData.CELL_SIZE)
	assert_eq(center, expected, "volume centered on the room at mid height")


func test_anchor_avoids_occupied_cells():
	# Occupy the room's central cells the way earlier steps would: dummy
	# spawn data on every cell of the middle column.
	var occupied := []
	for room_cell in _room_a().cell_indexes:
		var pos = data.get_int_position_from_cell_index(room_cell)
		if pos[0] == 3:
			var dummy := SpawnData.new()
			dummy.scene_path = "res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle_short.tscn"
			data.set_object_spawn_data_to_cell(room_cell, dummy)
			occupied.append(room_cell)
	assert_false(occupied.is_empty(), "test setup occupied at least one cell")

	_run_fog_step({_room_a(): FOG_SCENE})

	var fog_cells := _fog_spawn_cells()
	assert_eq(fog_cells.size(), 1, "fog still placed exactly once")
	assert_false(fog_cells[0] in occupied, "fog anchor is not an occupied cell")
	assert_true(fog_cells[0] in _room_a().cell_indexes, "fog anchor stays inside the room")


func test_fog_scenes_are_fog_volume_roots_with_fog_material():
	for path in [
		"res://scenes/effects/fog_room_volume_thick.tscn",
		"res://scenes/effects/fog_room_volume_swirl.tscn",
		"res://scenes/effects/fog_room_volume_half_height.tscn",
	]:
		var scene: PackedScene = load(path)
		assert_not_null(scene, "scene loads: " + path)
		var node = scene.instantiate()
		add_child_autofree(node)
		assert_eq(node.get_class(), "FogVolume", "root is a FogVolume: " + path)
		assert_eq(node.shape, RenderingServer.FOG_VOLUME_SHAPE_BOX, "box shape: " + path)
		assert_true(node.material is FogMaterial, "material is FogMaterial: " + path)
		assert_gt(node.material.density, 0.0, "positive density: " + path)
		assert_gt(node.material.edge_fade, 0.0, "soft edges enabled: " + path)
		node.free()


func test_game_environment_enables_volumetric_fog_with_zero_ambient_density():
	var env: Environment = load("res://scenes/worlds/game_environment.tres")
	assert_true(env.volumetric_fog_enabled, "volumetric fog enabled so FogVolumes render")
	assert_eq(env.volumetric_fog_density, 0.0, "zero ambient density so normal rooms show nothing")


func test_fountain_and_statue_purposes_carry_the_often_fog_rule():
	# Owner ruling: fountain and statue rooms are the often fogged ones, each
	# with its own per-purpose chance (owner amendment "Statue 50% fog"). The
	# rule lives on the room purpose resource and reaches the room through
	# generate_room_purposes.gd.
	var fountain: RoomPurpose = load("res://scenes/worlds/world_gen/helper_objects/room_purposes/fountain_room.tres")
	var statue: RoomPurpose = load("res://scenes/worlds/world_gen/helper_objects/room_purposes/statue_gallery.tres")
	assert_eq(fountain.fog_rule, RoomPurpose.FogRule.OFTEN, "fountain rooms fog often")
	assert_eq(fountain.fog_chance, 0.95, "fountain fog chance")
	assert_eq(statue.fog_rule, RoomPurpose.FogRule.OFTEN, "statue galleries fog often")
	assert_eq(statue.fog_chance, 0.5, "statue fog chance: owner amendment 50 percent")
	var crypt: RoomPurpose = load("res://scenes/worlds/world_gen/helper_objects/room_purposes/crypt.tres")
	var trophy: RoomPurpose = load("res://scenes/worlds/world_gen/helper_objects/room_purposes/trophy_room.tres")
	assert_eq(crypt.fog_rule, RoomPurpose.FogRule.SOMETIMES, "crypts keep the small sometimes default")
	assert_eq(crypt.fog_chance, 0.08, "crypts use the fallback chance")
	assert_eq(trophy.fog_rule, RoomPurpose.FogRule.SOMETIMES, "trophy rooms keep the small sometimes default")
	assert_eq(trophy.fog_chance, 0.08, "trophy rooms use the fallback chance")


func test_roomdata_default_fog_rule_is_sometimes():
	# Types without a purpose resource (staircases) fall back to the small
	# sometimes chance, so they do not fog much either.
	assert_eq(RoomData.new().fog_rule, RoomPurpose.FogRule.SOMETIMES,
		"rooms without a purpose default to the rare sometimes rule")
	assert_eq(RoomData.new().fog_chance, RoomPurpose.DEFAULT_FOG_CHANCE,
		"rooms without a purpose use the fallback fog chance")
