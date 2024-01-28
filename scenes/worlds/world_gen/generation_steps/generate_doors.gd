extends GenerationStep


@export var door_dict : Dictionary
@export var door_probability = 0.6
@export var door_stuck_probability = 0.2

const DOUBLE_DOOR_OFFSET_FROM_DIRECTION_N : Dictionary = {
	WorldData.Direction.NORTH : Vector3.ZERO,
	WorldData.Direction.EAST : Vector3.RIGHT*WorldData.CELL_SIZE,
	WorldData.Direction.SOUTH : Vector3.BACK*WorldData.CELL_SIZE,
	WorldData.Direction.WEST : Vector3.ZERO,
}

const DOUBLE_DOOR_OFFSET_FROM_DIRECTION_P : Dictionary = {
	WorldData.Direction.NORTH : Vector3.RIGHT*WorldData.CELL_SIZE,
	WorldData.Direction.EAST : (Vector3.RIGHT + Vector3.BACK)*WorldData.CELL_SIZE,
	WorldData.Direction.SOUTH : (Vector3.RIGHT + Vector3.BACK)*WorldData.CELL_SIZE,
	WorldData.Direction.WEST : Vector3.BACK*WorldData.CELL_SIZE,
}

const DOUBLE_DOOR_ADJACENT_DIRECTION_N : Dictionary = {
	WorldData.Direction.NORTH : WorldData.Direction.WEST,
	WorldData.Direction.EAST : WorldData.Direction.NORTH,
	WorldData.Direction.SOUTH : WorldData.Direction.WEST,
	WorldData.Direction.WEST : WorldData.Direction.NORTH,
}

const DOUBLE_DOOR_ADJACENT_DIRECTION_P : Dictionary = {
	WorldData.Direction.NORTH : WorldData.Direction.EAST,
	WorldData.Direction.EAST : WorldData.Direction.SOUTH,
	WorldData.Direction.SOUTH : WorldData.Direction.EAST,
	WorldData.Direction.WEST : WorldData.Direction.SOUTH,
}


func _get_transform_for_cell_direction(data : WorldData, cell_index : int, direction : int):
	pass


func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	# Dictionary of scene -> corresponding spawn data
	var doors_spawn_data : Dictionary = {}
	
	var random = RandomNumberGenerator.new()
	# Since each edge has 2 chances of getting a door, the probability used on each
	# chance should be a slighly different value, so that the total probability
	# matches the value set
	var partial_probability = 1 - sqrt(1 - door_probability)
	random.seed = generation_seed
	var game_world = GameManager.game.level
	# Sets a deterministic seed for the global random number generator
	seed(random.randi())
	# Shuffles cells to achieve random orientation
	var random_cell_order = range(data.cell_count)
	random_cell_order.shuffle()
	for cell in random_cell_order:
		for dir in data.Direction.DIRECTION_MAX:
			var wall_tile : int = data.get_wall_tile_index(cell, dir)
			var door_scene = door_dict.get(wall_tile)
			if door_scene is PackedScene:
				# Check if cell data allows door
				# Don't allow doors that opening towards a staircase room
				var room_data = data.get_cell_meta(cell, data.CellMetaKeys.META_ROOM_DATA) as RoomData
				if is_instance_valid(room_data) and	(
					room_data.type == RoomData.OriginalPurpose.DOWN_STAIRCASE or
					room_data.type == RoomData.OriginalPurpose.UP_STAIRCASE
				):
					continue
				
				# Comment this check out to allow doors that open away from a staircase room
#				var other_cell : int = data.get_neighbour_cell(cell, dir)
#				var other_room_data = data.get_cell_meta(other_cell, data.CellMetaKeys.META_ROOM_DATA) as RoomData
#				if is_instance_valid(other_room_data) and	(
#					other_room_data.type == RoomData.OriginalPurpose.DOWN_STAIRCASE or
#					other_room_data.type == RoomData.OriginalPurpose.UP_STAIRCASE
#				):
#					continue
				
				var has_door = data.get_wall_has_door(cell, dir)
				if not has_door and fposmod(random.randf(), 1.0) >= (1.0 - partial_probability):
#					var new_door = door_scene.instance() as Spatial
					var spawn_data = doors_spawn_data.get(door_scene) as SpawnData
					var door_data_index = 0;
					
					if not is_instance_valid(spawn_data):
						spawn_data = SpawnData.new()
						doors_spawn_data[door_scene] = spawn_data
						spawn_data.scene_path = door_scene.resource_path
					else:
						# Increase amount only if it doesn't exist, since it already starts with
						# an amount of 1
						door_data_index = spawn_data.amount
						spawn_data.amount += 1
					
					if fposmod(random.randf(), 1.0) < door_stuck_probability:
						spawn_data.set_custom_property("door_state", BaseKinematicDoor.DoorState.STUCK, door_data_index)
					
					var origin = Vector3.ZERO
					var basis = Basis.IDENTITY
					var rotation_basis = Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT)
					for i in dir:
						basis = rotation_basis * basis
					spawn_data.set_y_rotation(basis.get_euler().y, door_data_index)
					var cell_corner = data.get_local_cell_position(cell)
					var wall_type = data.get_wall_type(cell, dir)
					data.set_object_spawn_data_to_cell(cell, spawn_data)
					
					match wall_type:
						data.EdgeType.DOOR:
							origin = cell_corner + (Vector3(1, 0, 1) - basis.z) * 0.5 * data.CELL_SIZE
							data.set_wall_has_door(cell, dir, true)
							spawn_data.set_position_in_cell(origin, door_data_index)
						
						data.EdgeType.HALFDOOR_N:
							origin = cell_corner + DOUBLE_DOOR_OFFSET_FROM_DIRECTION_N[dir]
							data.set_wall_has_door(cell, dir, true)
							var neighbour_cell = data.get_neighbour_cell(cell, DOUBLE_DOOR_ADJACENT_DIRECTION_N[dir])
							data.set_wall_has_door(neighbour_cell, dir, true)
							spawn_data.set_position_in_cell(origin, door_data_index)
						
						data.EdgeType.HALFDOOR_P:
							origin = cell_corner + DOUBLE_DOOR_OFFSET_FROM_DIRECTION_P[dir]
							data.set_wall_has_door(cell, dir, true)
							var neighbour_cell = data.get_neighbour_cell(cell, DOUBLE_DOOR_ADJACENT_DIRECTION_P[dir])
							data.set_wall_has_door(neighbour_cell, dir, true)
							spawn_data.set_position_in_cell(origin, door_data_index)
