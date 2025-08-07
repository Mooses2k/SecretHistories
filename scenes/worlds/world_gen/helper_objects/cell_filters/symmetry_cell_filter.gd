class_name SymmetryCellFilter
extends CellFilter

## Handles symmetrical placement of objects in rooms
## Supports bilateral symmetry, mirrored placement, and equidistant positioning

enum SymmetryType {
	BILATERAL_HORIZONTAL,  # Mirror across horizontal center line
	BILATERAL_VERTICAL,    # Mirror across vertical center line
	RADIAL_CENTER,        # Equidistant from room center
	WALL_MIRROR,          # Mirror placement along opposite walls
	CORNER_DIAGONAL       # Diagonal corner symmetry
}

var symmetry_type: SymmetryType = SymmetryType.BILATERAL_HORIZONTAL
var require_exact_pairs: bool = true
var allow_center_object: bool = false


func filter_cells(world_data: WorldData, room_data: RoomData, rng: RandomNumberGenerator = null) -> Array:
	if not room_data:
		return []
	
	var room_rect := room_data.rect2
	var room_center := Vector2(
		room_rect.position.x + room_rect.size.x / 2.0,
		room_rect.position.y + room_rect.size.y / 2.0
	)
	
	match symmetry_type:
		SymmetryType.BILATERAL_HORIZONTAL:
			return _get_bilateral_horizontal_cells(world_data, room_data, room_rect, room_center)
		SymmetryType.BILATERAL_VERTICAL:
			return _get_bilateral_vertical_cells(world_data, room_data, room_rect, room_center)
		SymmetryType.RADIAL_CENTER:
			return _get_radial_center_cells(world_data, room_data, room_rect, room_center)
		SymmetryType.WALL_MIRROR:
			return _get_wall_mirror_cells(world_data, room_data, room_rect, room_center)
		SymmetryType.CORNER_DIAGONAL:
			return _get_corner_diagonal_cells(world_data, room_data, room_rect, room_center)
	
	return []


func _get_bilateral_horizontal_cells(world_data: WorldData, room_data: RoomData, room_rect: Rect2, room_center: Vector2) -> Array:
	var candidate_cells := []
	var room_cells := filter_available_cells(world_data, room_data.cell_indexes)
	
	for cell_index in room_cells:
		var cell_pos := get_int_position_from_cell(world_data, cell_index)
		var cell_x: int = cell_pos[0]
		var cell_y: int = cell_pos[1]
		
		var distance_from_center: float = cell_y - room_center.y
		var mirror_y: float = room_center.y - distance_from_center
		var mirror_cell_index := get_cell_index(world_data, cell_x, int(mirror_y))
		
		if mirror_cell_index >= 0 and is_cell_available(world_data, mirror_cell_index):
			if abs(distance_from_center) < 0.5:
				if allow_center_object:
					candidate_cells.append(cell_index)
			else:
				if require_exact_pairs:
					candidate_cells.append_array([cell_index, mirror_cell_index])
				else:
					candidate_cells.append(cell_index)
	
	return candidate_cells


func _get_bilateral_vertical_cells(world_data: WorldData, room_data: RoomData, room_rect: Rect2, room_center: Vector2) -> Array:
	var candidate_cells := []
	var room_cells := filter_available_cells(world_data, room_data.cell_indexes)
	
	for cell_index in room_cells:
		var cell_pos := get_int_position_from_cell(world_data, cell_index)
		var cell_x: int = cell_pos[0]
		var cell_y: int = cell_pos[1]
		
		var distance_from_center: float = cell_x - room_center.x
		var mirror_x: float = room_center.x - distance_from_center
		var mirror_cell_index := get_cell_index(world_data, int(mirror_x), cell_y)
		
		if mirror_cell_index >= 0 and is_cell_available(world_data, mirror_cell_index):
			if abs(distance_from_center) < 0.5:
				if allow_center_object:
					candidate_cells.append(cell_index)
			else:
				if require_exact_pairs:
					candidate_cells.append_array([cell_index, mirror_cell_index])
				else:
					candidate_cells.append(cell_index)
	
	return candidate_cells


func _get_radial_center_cells(world_data: WorldData, room_data: RoomData, room_rect: Rect2, room_center: Vector2) -> Array:
	var candidate_cells := []
	var room_cells := filter_available_cells(world_data, room_data.cell_indexes)
	
	# Group cells by distance from center
	var distance_groups := {}
	
	for cell_index in room_cells:
		var cell_pos := get_int_position_from_cell(world_data, cell_index)
		var cell_x: int = cell_pos[0]
		var cell_y: int = cell_pos[1]
		
		var distance := sqrt(pow(cell_x - room_center.x, 2) + pow(cell_y - room_center.y, 2))
		var distance_key := int(distance * 10)  # Group by tenths
		
		if not distance_groups.has(distance_key):
			distance_groups[distance_key] = []
		distance_groups[distance_key].append(cell_index)
	
	# Return cells that have matching distance partners
	for distance_key in distance_groups:
		var cells_at_distance: Array = distance_groups[distance_key]
		if cells_at_distance.size() >= 2 or (cells_at_distance.size() == 1 and allow_center_object):
			candidate_cells.append_array(cells_at_distance)
	
	return candidate_cells


func _get_wall_mirror_cells(world_data: WorldData, room_data: RoomData, room_rect: Rect2, room_center: Vector2) -> Array:
	var candidate_cells := []
	var wall_adjacent_cells := filter_cells_adjacent_to_walls(world_data, room_data.cell_indexes)
	var available_wall_cells := filter_available_cells(world_data, wall_adjacent_cells)
	
	# Find pairs of cells on opposite walls
	for cell_index in available_wall_cells:
		var cell_pos := get_int_position_from_cell(world_data, cell_index)
		var cell_x: int = cell_pos[0]
		var cell_y: int = cell_pos[1]
		
		# Check for horizontal mirror (opposite walls)
		var mirror_x: float = room_center.x * 2 - cell_x
		var h_mirror_cell := get_cell_index(world_data, int(mirror_x), cell_y)
		
		# Check for vertical mirror (opposite walls)
		var mirror_y: float = room_center.y * 2 - cell_y
		var v_mirror_cell := get_cell_index(world_data, cell_x, int(mirror_y))
		
		if (h_mirror_cell >= 0 and is_cell_available(world_data, h_mirror_cell) 
				and h_mirror_cell in available_wall_cells):
			candidate_cells.append_array([cell_index, h_mirror_cell])
		elif (v_mirror_cell >= 0 and is_cell_available(world_data, v_mirror_cell) 
				and v_mirror_cell in available_wall_cells):
			candidate_cells.append_array([cell_index, v_mirror_cell])
	
	return candidate_cells


func _get_corner_diagonal_cells(world_data: WorldData, room_data: RoomData, room_rect: Rect2, room_center: Vector2) -> Array:
	var candidate_cells := []
	
	# Get corner cells
	var corners := room_data.get_corners_data()
	var corner_cells := []
	
	for key in corners.corner_positions:
		var corner := corners.corner_positions[key] as Vector2
		var cell_index := get_cell_index(world_data, int(corner.x), int(corner.y))
		if is_cell_available(world_data, cell_index):
			corner_cells.append(cell_index)
	
	# Find diagonal pairs
	for i in range(corner_cells.size()):
		for j in range(i + 1, corner_cells.size()):
			var cell1: int = corner_cells[i]
			var cell2: int = corner_cells[j]
			var pos1 := get_int_position_from_cell(world_data, cell1)
			var pos2 := get_int_position_from_cell(world_data, cell2)
			
			# Check if they're diagonal (different x and y)
			if pos1[0] != pos2[0] and pos1[1] != pos2[1]:
				candidate_cells.append_array([cell1, cell2])
	
	return candidate_cells


func set_symmetry_type(type: SymmetryType) -> SymmetryCellFilter:
	symmetry_type = type
	return self


func set_require_exact_pairs(require: bool) -> SymmetryCellFilter:
	require_exact_pairs = require
	return self


func set_allow_center_object(allow: bool) -> SymmetryCellFilter:
	allow_center_object = allow
	return self