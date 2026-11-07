# Tests for the per-room reverb area placement in generate_room_reverb.gd
# (issue #179). Mirrors the fog volume placement contract: exactly ONE
# SpawnData per real room (never per cell), none for EMPTY-type corridor
# rooms, custom position/size properties matching the room footprint, an
# anchor on a free cell near the room center, and NO RNG draws so the
# generation seed stream stays untouched (two runs produce identical data).
extends GutTest

const ReverbStepScript = preload("res://scenes/worlds/world_gen/generation_steps/populate_room/generate_room_reverb.gd")

const ROOM_A_RECT := Rect2(2, 2, 4, 3)  # 4x3 cells
const ROOM_B_RECT := Rect2(8, 2, 3, 3)  # 3x3 cells
const REVERB_SCENE := "res://scenes/effects/room_reverb_area.tscn"

var data : WorldData


func before_each():
	GameManager.game = null
	data = WorldData.new()
	data.resize(16, 16)
	data.fill_room_data(ROOM_A_RECT, RoomData.OriginalPurpose.CRYPT)
	data.fill_room_data(ROOM_B_RECT, RoomData.OriginalPurpose.FOUNTAIN)


func _run_reverb_step() -> void:
	var step = ReverbStepScript.new()
	add_child_autofree(step)
	step._execute_step(data, {}, 12345)


func _reverb_spawn_cells() -> Array:
	var cells := []
	for cell_index in data.get_objects_to_spawn():
		var spawn_data = data.get_objects_to_spawn()[cell_index]
		if str(spawn_data.scene_path) == REVERB_SCENE:
			cells.append(cell_index)
	return cells


func test_one_area_per_real_room_never_one_per_cell():
	_run_reverb_step()
	var reverb_cells := _reverb_spawn_cells()
	assert_eq(reverb_cells.size(), 2, "exactly one reverb spawn per room")
	assert_eq(data.get_objects_to_spawn().size(), 2, "no other spawn data placed")
	var room_a: RoomData = data.get_rooms_of_type(RoomData.OriginalPurpose.CRYPT)[0]
	var room_b: RoomData = data.get_rooms_of_type(RoomData.OriginalPurpose.FOUNTAIN)[0]
	assert_true(reverb_cells[0] in room_a.cell_indexes or reverb_cells[0] in room_b.cell_indexes,
		"each anchor cell belongs to a real room")
	assert_true(reverb_cells[1] in room_a.cell_indexes or reverb_cells[1] in room_b.cell_indexes,
		"each anchor cell belongs to a real room")


func test_empty_type_rooms_are_skipped():
	var empty_rect := Rect2(2, 8, 2, 2)
	data.fill_room_data(empty_rect, RoomData.OriginalPurpose.EMPTY)
	_run_reverb_step()
	for cell_index in _reverb_spawn_cells():
		var pos = data.get_int_position_from_cell_index(cell_index)
		var inside_empty_room: bool = pos[0] >= empty_rect.position.x \
			and pos[0] < empty_rect.end.x and pos[1] >= empty_rect.position.y \
			and pos[1] < empty_rect.end.y
		assert_false(inside_empty_room, "empty-type corridor room got no reverb spawn")


func test_area_box_matches_room_footprint_with_buried_margin():
	_run_reverb_step()
	var spawn_data = data.get_objects_to_spawn()[_reverb_spawn_cells()[0]]
	var props: Dictionary = spawn_data._custom_properties[0]
	assert_true(props.has("position"), "box center custom property present")
	assert_true(props.has("size"), "box size custom property present")
	var center: Vector3 = props["position"]
	var box_size: Vector3 = props["size"]

	var room_min := Vector2(
		ROOM_A_RECT.position.x * WorldData.CELL_SIZE,
		ROOM_A_RECT.position.y * WorldData.CELL_SIZE)
	var room_max := Vector2(
		ROOM_A_RECT.end.x * WorldData.CELL_SIZE,
		ROOM_A_RECT.end.y * WorldData.CELL_SIZE)
	var margin := ReverbStepScript.HORIZONTAL_WALL_MARGIN

	# The box covers the whole room interior and grows only into the walls.
	assert_lte(center.x - box_size.x * 0.5, room_min.x + 0.01, "box covers the room's west edge")
	assert_gte(center.x + box_size.x * 0.5, room_max.x - 0.01, "box covers the room's east edge")
	assert_lte(center.z - box_size.z * 0.5, room_min.y + 0.01, "box covers the room's north edge")
	assert_gte(center.z + box_size.z * 0.5, room_max.y - 0.01, "box covers the room's south edge")
	assert_gte(center.x - box_size.x * 0.5, room_min.x - margin - 0.01, "box west edge stays inside the wall")
	assert_gte(center.z - box_size.z * 0.5, room_min.y - margin - 0.01, "box north edge stays inside the wall")

	# Vertical span: from below the floor slab to above the ceiling line.
	assert_lte(center.y - box_size.y * 0.5, -ReverbStepScript.VERTICAL_SLAB_MARGIN + 0.01,
		"box starts under the floor")
	assert_gte(center.y + box_size.y * 0.5, WorldData.WALL_SIZE + ReverbStepScript.VERTICAL_SLAB_MARGIN - 0.01,
		"box ends over the ceiling line")


func test_step_draws_no_rng_two_runs_are_identical():
	_run_reverb_step()
	var first_cells := _reverb_spawn_cells()
	var first_props := []
	for cell_index in first_cells:
		first_props.append(data.get_objects_to_spawn()[cell_index]._custom_properties[0].duplicate())

	data = WorldData.new()
	data.resize(16, 16)
	data.fill_room_data(ROOM_A_RECT, RoomData.OriginalPurpose.CRYPT)
	data.fill_room_data(ROOM_B_RECT, RoomData.OriginalPurpose.FOUNTAIN)
	_run_reverb_step()
	var second_cells := _reverb_spawn_cells()
	assert_eq(first_cells, second_cells, "anchor cells are deterministic across runs")
	for index in first_cells.size():
		var first: Dictionary = first_props[index]
		var second: Dictionary = data.get_objects_to_spawn()[second_cells[index]]._custom_properties[0]
		assert_eq(second["position"], first["position"], "box center is deterministic")
		assert_eq(second["size"], first["size"], "box size is deterministic")


func test_anchor_avoids_occupied_cells():
	var occupied := []
	for room_cell in data.get_rooms_of_type(RoomData.OriginalPurpose.CRYPT)[0].cell_indexes:
		var pos = data.get_int_position_from_cell_index(room_cell)
		if pos[0] == 3:
			var dummy := SpawnData.new()
			dummy.scene_path = "res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle_short.tscn"
			data.set_object_spawn_data_to_cell(room_cell, dummy)
			occupied.append(room_cell)
	assert_false(occupied.is_empty(), "test setup occupied at least one cell")

	_run_reverb_step()
	var reverb_cells := _reverb_spawn_cells()
	assert_eq(reverb_cells.size(), 2, "reverb still placed once per room")
	assert_false(reverb_cells[0] in occupied, "reverb anchor is not an occupied cell")
	assert_true(reverb_cells[0] in data.get_rooms_of_type(RoomData.OriginalPurpose.CRYPT)[0].cell_indexes,
		"reverb anchor stays inside the room")
