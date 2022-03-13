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
const ROTATE_LEFT = [
	Direction.WEST,
	Direction.NORTH,
	Direction.EAST,
	Direction.SOUTH,
]

const INVERSE = [
	Direction.SOUTH,
	Direction.WEST,
	Direction.NORTH,
	Direction.EAST,
]

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

const CELL_SIZE : float = 1.5
const WALL_SIZE : float = 3.0
const WALL_DISTANCE : float = 0.15

var world_size_x : int = 16 setget set_world_size_x
var world_size_z : int = 16 setget set_world_size_z
var cell_count : int = world_size_x*world_size_z

func set_world_size_x(value : int):
	world_size_x = value
	update_cell_count()

func set_world_size_z(value : int):
	world_size_z = value
	update_cell_count()

func update_cell_count():
	cell_count = world_size_x*world_size_z
	is_cell_free.resize(cell_count)
	wall_type_x.resize(cell_count + world_size_z)
	wall_type_z.resize(cell_count + world_size_x)
	ground_tile_index.resize(cell_count)
	wall_tile_index_xn.resize(cell_count)
	wall_tile_index_xp.resize(cell_count)
	wall_tile_index_zn.resize(cell_count)
	wall_tile_index_zp.resize(cell_count)
	pillar_tile_index.resize((world_size_x + 1)*(world_size_z + 1))
	ceiling_tile_index.resize(cell_count)
	pass


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

#Stores wether a given cell is free (walkable) or not, using the following indexing method
# ┌───┬───┬───┬─►X
# │ 0 │ 2 │ 4 │
# ├───┼───┼───┤
# │ 1 │ 3 │ 5 │
# ├───┴───┴───┘
# │
# ▼
# Z

var is_cell_free : PoolByteArray

#Stores wall types for edges that are X aligned (face the Z axis) , as in the following diagram
# ┌─0─┬─3─┬─6─┬─►X
# │   │   │   │
# ├─1─┼─4─┼─7─┤
# │   │   │   │
# ├─2─┴─5─┴─8─┘
# │
# ▼
# Z
var wall_type_z : PoolByteArray
# additional data for wall type, stored as { id: value}, where id is the wall id on the type array
var wall_meta_z : Dictionary
# Stores a reference to the in-world door object relative to each wall that contains a door
var doors_z : Dictionary

#Stores wall types for edges that are Z aligned (face the X axis), as in the following diagram
# ┌───┬───┬───┬─►X
# 0   2   4   6
# ├───┼───┼───┤
# 1   3   5   7
# ├───┴───┴───┘
# │
# ▼
# Z
var wall_type_x : PoolByteArray
# additional data for wall type, stored as { id: value}, where id is the wall id on the type array
var wall_meta_x : Dictionary
# Stores a reference to the in-world door object relative to each wall that contains a door
var doors_x : Dictionary

#Stores the pillar radius for each corner index, as shown
# 0───3───6───9─►X
# │   │   │   │
# 1───4───7──10
# │   │   │   │
# 2───5───8──11
# │
# ▼
# Z
#
var pillar_radius : Dictionary

#Stores the tiles used for each cell
var ground_tile_index : PoolIntArray
var wall_tile_index_xp : PoolIntArray
var wall_tile_index_xn : PoolIntArray
var wall_tile_index_zp : PoolIntArray
var wall_tile_index_zn : PoolIntArray
var pillar_tile_index : PoolIntArray
var ceiling_tile_index : PoolIntArray

func get_cell_index_from_position(pos : Vector3) -> int:
	pos /= CELL_SIZE
	return get_cell_index_from_int_position(pos.x, pos.z)

func get_cell_index_from_int_position(x : int, z : int) -> int:
	return x*world_size_z + z

func get_pillar_index_from_int_position(x : int, z : int) -> int:
	return x*(world_size_z + 1) + z

func set_pillar(pillar_index : int, tile_index : int = -1, radius = null):
	pillar_tile_index[pillar_index] = tile_index
	if radius == null:
		if pillar_radius.has(pillar_index):
			pillar_radius.erase(pillar_index)
	else:
		pillar_radius[pillar_index] = radius

func get_int_position_from_cell_index(cell_index : int) -> Array:
	return [int(cell_index/world_size_z), cell_index%world_size_z]

func get_cell_position(cell_index : int) -> Vector3:
	return Vector3(int(cell_index/world_size_z), 0, cell_index%world_size_z)*CELL_SIZE

#TODO
func get_north_wall_index(cell_index : int) -> int:
	return cell_index

func get_south_wall_index(cell_index : int) -> int:
	return cell_index + 1

func get_west_wall_index(cell_index : int) -> int:
	var cell_x = int(cell_index/world_size_z)
	var cell_z = cell_index%world_size_z
	return cell_x*(world_size_z) + cell_z

func get_east_wall_index(cell_index : int) -> int:
	var cell_x = int(cell_index/world_size_z) + 1
	var cell_z = cell_index%world_size_z
	return cell_x*(world_size_z) + cell_z

func get_wall_type(cell_index : int, direction : int) -> int:
	var idx = 0
	match direction:
		Direction.NORTH:
			idx = get_north_wall_index(cell_index)
		Direction.SOUTH:
			idx = get_south_wall_index(cell_index)
		Direction.EAST:
			idx = get_east_wall_index(cell_index)
		Direction.WEST:
			idx = get_west_wall_index(cell_index)
	if direction == Direction.NORTH or direction == Direction.SOUTH:
		return wall_type_z[idx]
	return wall_type_x[idx]

func set_wall_type(cell_index : int, direction : int, value : int):
	var idx = 0
	match direction:
		Direction.NORTH:
			idx = get_north_wall_index(cell_index)
		Direction.SOUTH:
			idx = get_south_wall_index(cell_index)
		Direction.EAST:
			idx = get_east_wall_index(cell_index)
		Direction.WEST:
			idx = get_west_wall_index(cell_index)
	if direction == Direction.NORTH or direction == Direction.SOUTH:
		wall_type_z[idx] = value
	else:
		wall_type_x[idx] = value

func get_wall_meta(cell_index : int, direction : int) -> int:
	var idx = 0
	match direction:
		Direction.NORTH:
			idx = get_north_wall_index(cell_index)
		Direction.SOUTH:
			idx = get_south_wall_index(cell_index)
		Direction.EAST:
			idx = get_east_wall_index(cell_index)
		Direction.WEST:
			idx = get_west_wall_index(cell_index)
	var dict : Dictionary = wall_meta_x
	if direction == Direction.NORTH or direction == Direction.SOUTH:
		dict = wall_meta_z
	return dict.get(idx)

func set_wall_meta(cell_index : int, direction : int, value = null):
	var idx = 0
	match direction:
		Direction.NORTH:
			idx = get_north_wall_index(cell_index)
		Direction.SOUTH:
			idx = get_south_wall_index(cell_index)
		Direction.EAST:
			idx = get_east_wall_index(cell_index)
		Direction.WEST:
			idx = get_west_wall_index(cell_index)
	var dict : Dictionary = wall_meta_x
	if direction == Direction.NORTH or direction == Direction.SOUTH:
		dict = wall_meta_z
	if value == null:
		if dict.has(idx):
			(dict as Dictionary).erase(idx)
	else:
		dict[idx] = value

func get_wall_tile_index(cell_index : int, direction : int) -> int:
	match direction:
		Direction.NORTH:
			return wall_tile_index_zn[cell_index]
		Direction.EAST:
			return wall_tile_index_xp[cell_index]
		Direction.SOUTH:
			return wall_tile_index_zp[cell_index]
		Direction.WEST:
			return wall_tile_index_xn[cell_index]
	return -1

func set_wall_tile_index(cell_index : int, direction : int, value : int):
	match direction:
		Direction.NORTH:
			wall_tile_index_zn[cell_index] = value
		Direction.EAST:
			wall_tile_index_xp[cell_index] = value
		Direction.SOUTH:
			wall_tile_index_zp[cell_index] = value
		Direction.WEST:
			wall_tile_index_xn[cell_index] = value

func set_wall(cell_index : int, direction : int, wall_type : int = EdgeType.EMPTY, tile_index : int = -1, meta_value = null):
	set_wall_type(cell_index, direction, wall_type)
	set_wall_meta(cell_index, direction, meta_value)
	set_wall_tile_index(cell_index, direction, tile_index)
	pass

func get_north_cell(cell_index : int) -> int:
	return cell_index - 1

func get_south_cell(cell_index : int) -> int:
	return cell_index + 1

func get_west_cell(cell_index : int) -> int:
	return cell_index - world_size_z

func get_east_cell(cell_index : int) -> int:
	return cell_index + world_size_z

func get_neighbour_cell(cell_index : int, direction : int) -> int:
	match direction:
		Direction.NORTH:
			return get_north_cell(cell_index)
		Direction.SOUTH:
			return get_south_cell(cell_index)
		Direction.EAST:
			return get_east_cell(cell_index)
		Direction.WEST:
			return get_west_cell(cell_index)
	return cell_index

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
			"name" : "rooms",
			"type" : TYPE_DICTIONARY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "is_cell_free",
			"type" : TYPE_RAW_ARRAY,
			"usage" : PROPERTY_USAGE_STORAGE
		},

		{
			"name" : "wall_type_x",
			"type" : TYPE_RAW_ARRAY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "wall_meta_x",
			"type" : TYPE_DICTIONARY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "doors_x",
			"type" : TYPE_DICTIONARY,
			"usage" : PROPERTY_USAGE_STORAGE
		},

		{
			"name" : "wall_type_z",
			"type" : TYPE_RAW_ARRAY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "wall_meta_z",
			"type" : TYPE_DICTIONARY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "doors_z",
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
			"name" : "wall_tile_index_xp",
			"type" : TYPE_INT_ARRAY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "wall_tile_index_xn",
			"type" : TYPE_INT_ARRAY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "wall_tile_index_zp",
			"type" : TYPE_INT_ARRAY,
			"usage" : PROPERTY_USAGE_STORAGE
		},
		{
			"name" : "wall_tile_index_zn",
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
