# Tests for the 2x2 slot centering math in generate_statue_gallery.gd.
# Expected numbers come from docs/research/statue-trophy-placement-scale-fix.md:
# cell positions are corners, so a plain 2x2 slot center is one full cell along
# the wall plus one full cell into the room; SOUTH/EAST walls sit on the max
# edge (width offset 0), NORTH/WEST on the min edge (+1 cell into the room).
extends GutTest

const GalleryScript = preload("res://scenes/worlds/world_gen/generation_steps/populate_room/generate_statue_gallery.gd")
const WallFilterScript = preload("res://scenes/worlds/world_gen/helper_objects/cell_filters/wall_segment_cell_filter.gd")

const CELL := WorldData.CELL_SIZE

var _step = null
var _data = null


func before_each():
	_data = WorldData.new()
	_step = GalleryScript.new()


func after_each():
	if is_instance_valid(_step):
		_step.free()
	_data = null


func _offset(direction : int) -> Vector3:
	return _step._get_slot_center_offset(_data, 0, direction)


func test_center_placement_has_no_offset():
	assert_eq(_offset(-1), Vector3.ZERO, "center slots carry the 2x2 offset in slot_offset already")


func test_north_slot_center_is_one_cell_along_wall_and_one_into_room():
	# length = EAST (1,0), width = SOUTH (0,1), no correction for NORTH.
	assert_eq(_offset(WorldData.Direction.NORTH), Vector3(CELL, 0.0, CELL))


func test_south_edge_correction_makes_width_offset_zero():
	# width = NORTH (0,-1) corrected by SOUTH (0,1) => 0; length = EAST (1,0).
	assert_eq(_offset(WorldData.Direction.SOUTH), Vector3(CELL, 0.0, 0.0))


func test_east_edge_correction_makes_width_offset_zero():
	# EAST uses the CW length branch: length = SOUTH (0,+1) along the wall;
	# width = WEST (-1,0) corrected by EAST (1,0) => 0 into the room.
	assert_eq(_offset(WorldData.Direction.EAST), Vector3(0.0, 0.0, CELL))


func test_west_correction_adds_one_cell_into_room():
	# WEST uses the CCW length branch: length = SOUTH (0,+1) along the wall;
	# width = EAST (1,0), no correction for WEST.
	assert_eq(_offset(WorldData.Direction.WEST), Vector3(CELL, 0.0, CELL))


func test_surplus_slot_stacks_half_cell_filter_wall_offset_on_center_offset():
	# Surplus slots get the filter's half-cell wall_offset along the wall
	# (in cell units, multiplied by CELL_SIZE at the call site), stacked on
	# top of _get_slot_center_offset. Example: NORTH wall with 1 surplus cell.
	# WallSegmentCellFilter extends a RefCounted Resource; never free() it.
	var filter = WallFilterScript.new()
	var wall_offset_in_cells := filter._get_wall_offset(WorldData.Direction.NORTH, 1)
	assert_eq(wall_offset_in_cells, Vector3(0.5, 0.0, 0.0), "surplus of 1 cell centers by half a cell along the wall")
	var stacked := _offset(WorldData.Direction.NORTH) + wall_offset_in_cells * CELL
	assert_eq(stacked, Vector3(CELL * 1.5, 0.0, CELL), "NORTH surplus spawn = corner + 1.5 cell along wall + 1 cell into room")


func test_surplus_wall_offset_runs_along_the_wall_for_east_west_walls():
	var filter = WallFilterScript.new()
	var east := filter._get_wall_offset(WorldData.Direction.EAST, 1)
	var west := filter._get_wall_offset(WorldData.Direction.WEST, 2)
	assert_eq(east, Vector3(0.0, 0.0, 0.5), "EAST wall offset runs along z")
	assert_eq(west, Vector3(0.0, 0.0, 1.0), "EAST/WEST wall offset runs along z, scaled by surplus")
