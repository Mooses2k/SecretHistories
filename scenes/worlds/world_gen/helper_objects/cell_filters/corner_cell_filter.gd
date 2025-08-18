class_name CornerCellFilter
extends CellFilter

## Filters for room corner cells
## Consolidates logic from generate_candelabra.gd:68-99

var avoid_doors: bool = true


func filter_cells(world_data: WorldData, room_data: RoomData, rng: RandomNumberGenerator = null) -> Array:
	if not room_data:
		return []
	
	# Get corner positions using RoomData (this is room-specific, not WorldData)
	var corners = room_data.get_corners_data()
	var corner_cells := []
	
	# Convert corner positions to cell indexes using base class utility
	for key in corners.corner_positions:
		var corner = corners.corner_positions[key] as Vector2
		var cell_index = get_cell_index(world_data, int(corner.x), int(corner.y))
		corner_cells.append(cell_index)
	
	# Filter available corners using base class utility
	var available_corners = filter_available_cells(world_data, corner_cells)
	
	# Filter out corners near doors if requested using base class utility
	if avoid_doors:
		available_corners = filter_cells_away_from_doors(world_data, available_corners)
	
	return available_corners


func set_avoid_doors(avoid: bool) -> CornerCellFilter:
	avoid_doors = avoid
	return self