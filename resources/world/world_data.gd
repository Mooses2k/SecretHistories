extends Resource
class_name WorldData

enum Direction {
	NORTH,
	EAST,
	SOUTH,
	WEST,
	DIRECTION_MAX,
}

const ROTATE_RIGHT = [
	Direction.EAST,
	Direction.SOUTH,
	Direction.WEST,
	Direction.NORTH,
]

func direction_rotate_cw(dir : int) -> int:
	return ROTATE_RIGHT[dir]

const ROTATE_LEFT = [
	Direction.WEST,
	Direction.NORTH,
	Direction.EAST,
	Direction.SOUTH,
]

func direction_rotate_ccw(dir : int) -> int:
	return ROTATE_LEFT[dir]

const INVERSE = [
	Direction.SOUTH,
	Direction.WEST,
	Direction.NORTH,
	Direction.EAST,
]

func direction_inverse(dir : int) -> int:
	return INVERSE[dir]

# This could be make dynamic in the future, to allow algorithms to use
# many different cell types with different properties
enum CellType {
	# Empty Cell, which means the cell itself is out of bounds
	EMPTY,
	
	# The cell belongs to a room
	ROOM,
	
	# The cell belongs to a corridor
	CORRIDOR,
	
	# The cell belongs to a Hall, which is an area enclosed by a corridor
	HALL
	
	# The cell has a door in some direction, meta data is an Array of Directions
	# indicating the directions, from this cell, where one can find a door
	DOOR,
}

enum CellMetaKeys {
	META_DOOR_DIRECTIONS,
	META_PILLAR_ROOM,
}

enum EdgeType {
	#Impassable wall
	WALL,
	
	#Centralized door, width stored on meta dict
	DOOR,
	
	#Door offset towards the negative coordinate direction
	# (i.e, if the door is along the x axis, the opening is on the corner with lower x value)
	# width stored on meta dict
	HALFDOOR_N,
	
	#Door offset towards the positive coordinate direction
	# width stored on meta dict
	HALFDOOR_P,
	
	#No wall
	EMPTY
}

enum SurfaceType {
	WOOD,
	CARPET,
	STONE,
	WATER,
	GRAVEL,
	METAL, 
	TILE
}

var cell_surface_type : PoolByteArray

# Physical parameters of the world
const CELL_SIZE : float = 1.5
const WALL_SIZE : float = 3.0
const WALL_DISTANCE : float = 0.15

# The size of the world, as a number of cells
var world_size_x : int = 16
var world_size_z : int = 16
var cell_count : int = world_size_x*world_size_z

func resize(size_x : int, size_z : int):
	world_size_x = size_x
	world_size_z = size_z
	clear()

func get_size_x() -> int:
	return world_size_x

func get_size_z() -> int:
	return world_size_z

# Clears all the data, resetting everything back to default values
func clear():
	cell_count = world_size_x*world_size_z
	cell_type.resize(cell_count)
	cell_surface_type.resize(cell_count)
	ground_tile_index.resize(cell_count)
	ceiling_tile_index.resize(cell_count)
	pillar_tile_index.resize(cell_count)
	for i in cell_count:
		cell_type[i] = CellType.EMPTY
		ground_tile_index[i] = -1
		ceiling_tile_index[i] = -1
		pillar_tile_index[i] = -1
	
	wall_tile_index.resize(4*cell_count)
	for i in wall_tile_index.size():
		wall_tile_index[i] = -1
	
	wall_type.resize(2*cell_count + world_size_x + world_size_z)
	for i in wall_type.size():
		wall_type[i] = EdgeType.EMPTY
	
	cell_meta.clear()
	rooms.clear()
	wall_meta.clear()
	doors.clear()
	pillar_radius.clear()


# Room definitions, store as a dictionary as follows:
# {
# 	room_type_1 : [polygon_1, polygon_2, ...]
#	room_type_2 : [polygon_1, polygon_2, ...]
#	...
# }
# where each room_type key is a string defining the type of the rooms (i.e., "armory")
# and each associated value containing an array of polygons, each representing
# a single room as a poolvector2array of points in grid space
var rooms : Dictionary

# Stores the type of a cell as a variant of the CellType enum, following the
# indexing below
# ┌───┬───┬───┬─►X
# │ 0 │ 2 │ 4 │
# ├───┼───┼───┤
# │ 1 │ 3 │ 5 │
# ├───┴───┴───┘
# │
# ▼
# Z
var cell_type : PoolByteArray

# Stores meta data for any cell if required by the cell's type, (for example, a
# Cell of type door would store the direction the door points toward)
# the key is the cell index, the value depends on the cell type
var cell_meta : Dictionary = Dictionary()

#Stores wall types for all edges, following the indexing below
# ┌─0─┬─3─┬─6─┬─►X
# 9   11  13  15
# ├─1─┼─4─┼─7─┤
# 10  12  14  16
# ├─2─┴─5─┴─8─┘
# │
# ▼
# Z
# All X aligned walls are stored in sequence, and then all of the Z aligned walls
# are stores in sequence after that
var wall_type : PoolByteArray
# additional data for wall type, stored as { id: value}, where id is the wall id on the type array
var wall_meta : Dictionary
# Stores a reference to the in-world door object relative to each wall that contains a door
var doors : Dictionary

# Stores the pillar radius for each corner index, as shown
# Note that there are no indexes corresponding to any positions on the
# East-most and South-most sides of the dungeon. World gen algorithms should
# not generating any non-empty cells at the border of the world, so that doesn't
# cause any issues
# 0───2───4───┬─►X
# │   │   │   │
# 1───3───5───┤
# │   │   │   │
# ├───┴───┴───┘
# │
# ▼
# Z
#
var pillar_radius : Dictionary

#Stores the tiles used for each cell
var ground_tile_index : PoolIntArray
# the 4 tile indexes for the 4 walls of each cell are stored in sequence, following
# the Direction enum values, so, for example, the North wall of cell I is at (4*I + North)
var wall_tile_index : PoolIntArray
var pillar_tile_index : PoolIntArray
var ceiling_tile_index : PoolIntArray


func _get_property_list() -> Array:
	return [
		{
			"name" : "world_size_x",
			"type" : TYPE_INT,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "world_size_z",
			"type" : TYPE_INT,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "cell_count",
			"type" : TYPE_INT,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "rooms",
			"type" : TYPE_DICTIONARY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "cell_type",
			"type" : TYPE_RAW_ARRAY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "cell_meta",
			"type" : TYPE_DICTIONARY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "wall_type",
			"type" : TYPE_RAW_ARRAY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "wall_meta",
			"type" : TYPE_DICTIONARY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "doors",
			"type" : TYPE_DICTIONARY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "pillar_radius",
			"type" : TYPE_DICTIONARY,
			"usage" : PROPERTY_USAGE_STORAGE
		},

		{
			"name" : "ground_tile_index",
			"type" : TYPE_INT_ARRAY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "wall_tile_index",
			"type" : TYPE_INT_ARRAY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "pillar_tile_index",
			"type" : TYPE_INT_ARRAY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "ceiling_tile_index",
			"type" : TYPE_INT_ARRAY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
	]



func get_cell_index_from_local_position(pos : Vector3) -> int:
	pos /= CELL_SIZE
	return get_cell_index_from_int_position(pos.x, pos.z)


func get_cell_index_from_int_position(x : int, z : int) -> int:
	if x < 0 or x >= world_size_x or z < 0 or z > world_size_z:
		printerr("Position (", x, ", ", z, ") Is out of bounds")
		return -1
	return x*world_size_z + z


func set_pillar(cell_index : int, tile_index : int = -1, radius : float = -1.0):
	set_pillar_tile_index(cell_index, tile_index)
	set_pillar_radius(cell_index, radius)


func set_pillar_tile_index(cell_index : int, tile_index : int = -1):
	pillar_tile_index[cell_index] = tile_index


func get_pillar_tile_index(cell_index : int) -> int:
	return pillar_tile_index[cell_index]


func set_pillar_radius(cell_index : int, radius : float = -1.0):
	if radius <= 0.0:
		pillar_radius.erase(cell_index)
	else:
		pillar_radius[cell_index] = radius


func get_pillar_radius(cell_index : int) -> float:
	return pillar_radius.get(cell_index, -1.0)


func set_ground_tile_index(cell_index : int, tile_index : int = -1):
	ground_tile_index[cell_index] = tile_index


func get_ground_tile_index(cell_index : int) -> int:
	return ground_tile_index[cell_index]


func set_ceiling_tile_index(cell_index : int, tile_index : int = -1):
	ceiling_tile_index[cell_index] = tile_index


func get_ceiling_tile_index(cell_index : int) -> int:
	return ceiling_tile_index[cell_index]


func get_int_position_from_cell_index(cell_index : int) -> Array:
	return [int(cell_index/world_size_z), cell_index%world_size_z]


func get_local_cell_position(cell_index : int) -> Vector3:
	return Vector3(int(cell_index/world_size_z), 0, cell_index%world_size_z)*CELL_SIZE


func get_cell_type(cell_index : int) -> int:
	return cell_type[cell_index] if cell_index >= 0 else -1


func set_cell_type(cell_index : int, value : int):
	if cell_index >= 0:
		cell_type[cell_index] = value


func get_cell_surfacetype(cell_index : int) -> int:
	return cell_surface_type[cell_index] if cell_index >= 0 else -1


func set_cell_surfacetype(cell_index : int, value : int):
	if cell_index >= 0:
		cell_surface_type[cell_index] = value


func get_cell_meta(cell_index : int, key, default = null):
	var meta = cell_meta.get(cell_index, Dictionary()) as Dictionary
	if meta:
		return meta.get(key, default)
	return default

func set_cell_meta(cell_index : int, key, value):
	if cell_index >= 0:
		var meta = cell_meta.get(cell_index, Dictionary()) as Dictionary
		if value == null:
			meta.erase(key)
		else:
			meta[key] = value
		if meta.empty():
			cell_meta.erase(cell_index)
		cell_meta[cell_index] = meta
			

func has_cell_meta(cell_index : int, key):
	var meta = cell_meta.get(cell_index, Dictionary()) as Dictionary
	if meta:
		return meta.has(key)
	return false

func cell_meta_get_keys(cell_index : int) -> Array:
	return (cell_meta.get(cell_index, Dictionary()) as Dictionary).keys()

func clear_cell_meta(cell_index : int):
	cell_meta.erase(cell_index)

func _get_north_wall_index(cell_index : int) -> int:
	return cell_index + int(cell_index/world_size_z)


func _get_south_wall_index(cell_index : int) -> int:
	return _get_north_wall_index(cell_index) + 1


func _get_west_wall_index(cell_index : int) -> int:
	return cell_index + cell_count + world_size_x


func _get_east_wall_index(cell_index : int) -> int:
	return _get_west_wall_index(cell_index) + world_size_z


func _get_wall_index(cell_index : int, direction : int) -> int:
	if cell_index < 0:
		return -1
	match direction:
		Direction.NORTH:
			return _get_north_wall_index(cell_index)
		Direction.SOUTH:
			return _get_south_wall_index(cell_index)
		Direction.EAST:
			return _get_east_wall_index(cell_index)
		Direction.WEST:
			return _get_west_wall_index(cell_index)
	return -1


func get_wall_type(cell_index : int, direction : int) -> int:
	var idx = _get_wall_index(cell_index, direction)
	return wall_type[idx] if idx >= 0 else -1


func set_wall_type(cell_index : int, direction : int, value : int):
	var idx = _get_wall_index(cell_index, direction)
	if idx >= 0:
		wall_type[idx] = value


func get_wall_meta(cell_index : int, direction : int):
	var idx = _get_wall_index(cell_index, direction)
	return wall_meta.get(idx)


func set_wall_meta(cell_index : int, direction : int, value = null):
	var idx = _get_wall_index(cell_index, direction)
	if idx >= 0:
		if value == null:
			wall_meta.erase(idx)
		else:
			wall_meta[idx] = value


func get_wall_tile_index(cell_index : int, direction : int) -> int:
	return wall_tile_index[4*cell_index + direction]


func set_wall_tile_index(cell_index : int, direction : int, value : int):
	wall_tile_index[4*cell_index + direction] = value


func set_wall(cell_index : int, direction : int, wall_type : int = EdgeType.EMPTY, tile_index : int = -1, meta_value = null):
	set_wall_type(cell_index, direction, wall_type)
	set_wall_meta(cell_index, direction, meta_value)
	set_wall_tile_index(cell_index, direction, tile_index)


func _get_north_cell(cell_index : int) -> int:
	if cell_index%world_size_z != 0:
		return cell_index - 1
	return -1


func _get_south_cell(cell_index : int) -> int:
	if cell_index%world_size_z != world_size_z - 1:
		return cell_index + 1
	return -1


func _get_west_cell(cell_index : int) -> int:
	if cell_index > world_size_z:
		return cell_index - world_size_z
	return -1


func _get_east_cell(cell_index : int) -> int:
	if cell_index < cell_count - world_size_z:
		return cell_index + world_size_z
	return -1


func get_neighbour_cell(cell_index : int, direction : int) -> int:
	if cell_index < 0:
		return -1
	match direction:
		Direction.NORTH:
			return _get_north_cell(cell_index)
		Direction.SOUTH:
			return _get_south_cell(cell_index)
		Direction.EAST:
			return _get_east_cell(cell_index)
		Direction.WEST:
			return _get_west_cell(cell_index)
	return -1
