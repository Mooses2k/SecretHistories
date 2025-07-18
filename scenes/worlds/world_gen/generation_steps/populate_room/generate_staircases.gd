# Write your doc string for this file here
extends GenerationStep

#- Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const PATH_UP_STAIRCASE = "res://scenes/objects/large_objects/staircases/staircase_up.tscn"
const PATH_DOWN_STAIRCASE = "res://scenes/objects/large_objects/staircases/staircase_down.tscn"

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

#--------------------------------------------------------------------------------------------------


#- Built-in Virtual Overrides --------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------


#- Public Methods --------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------


#- Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	var staircase_rooms := []
	staircase_rooms.append_array(data.get_rooms_of_type(RoomData.OriginalPurpose.UP_STAIRCASE))
	staircase_rooms.append_array(data.get_rooms_of_type(RoomData.OriginalPurpose.DOWN_STAIRCASE))
	for room in staircase_rooms:
		_populate_staircase(room, data)


func _populate_staircase(room: RoomData, world_data: WorldData) -> void:
	var spawn_data := ItemSpawnData.new()
	if room.type == room.OriginalPurpose.UP_STAIRCASE:
		spawn_data.scene_path = PATH_UP_STAIRCASE
	elif room.type == room.OriginalPurpose.DOWN_STAIRCASE:
		spawn_data.scene_path = PATH_DOWN_STAIRCASE
	else:
		push_error("Not a staircase room | room_data: %s"%[room])
		return
	
	var door_directions := room.get_doorway_directions()
	if door_directions.size() > 1:
		push_error("Staircase room has more than 1 doors | room_data: %s"%[room])
	elif door_directions.is_empty():
		push_error("Staircase room has no doors, aborting staircase | room_data: %s"%[room])
		return
	
	var cell_index := world_data.get_cell_index_from_int_position(
			room.rect2.position.x, room.rect2.position.y
	)
	var cell_position := \
			world_data.get_local_cell_position(cell_index) \
			+ Vector3(world_data.CELL_SIZE, 0, world_data.CELL_SIZE)
	var door_direction := door_directions[0] as int
	spawn_data.set_position_in_cell(cell_position)
	spawn_data.set_custom_property("facing_direction", door_direction)
	
	_update_world_data(spawn_data, door_direction, room, world_data)

#--------------------------------------------------------------------------------------------------


#- Signal Callbacks ------------------------------------------------------------------------------

func _update_world_data(
		spawn_data: ItemSpawnData,
		door_direction: WorldData.Direction,
		room: RoomData, 
		world_data: WorldData, 
) -> void:
	var cell_closest_to_door := _get_closest_cell_to_door(room.cell_indexes, door_direction)
	if not world_data.player_spawn_positions.has(room.type):
		world_data.player_spawn_positions[room.type] = {}
	
	world_data.player_spawn_positions[room.type][cell_closest_to_door] = {
		"cell_indexes": room.cell_indexes,
	}
	
	for index in room.cell_indexes:
		world_data.set_object_spawn_data_to_cell(index, spawn_data)


## Assumes cell_indexes is of size 4, describing a room like:
## 0, 2
## 1, 3
func _get_closest_cell_to_door(cell_indexes: Array, facing_direction: WorldData.Direction) -> int:
	var index := -1
	if cell_indexes.is_empty():
		push_error("Code shouldn't have reached here, a staircase room can't have zero cells")
		return index
	elif cell_indexes.size() != 4:
		push_error("Staircase Rooms are expected to be 4 cells. Revise this code if you get this error")
		index = 0
		return cell_indexes[index]
	
	match facing_direction:
		WorldData.Direction.NORTH:
			index = 0
		WorldData.Direction.EAST:
			index = 2
		WorldData.Direction.SOUTH:
			index = 3
		WorldData.Direction.WEST:
			index = 1
		WorldData.Direction.DIRECTION_MAX:
			var msg := "Invalid direction for staircase"
			msg += ", something must be fixed in what is being passed here"
			assert(facing_direction != WorldData.Direction.DIRECTION_MAX, msg)
		_:
			assert(index != -1, "New value in WoldData.Directions, include it in this match")
	
	return cell_indexes[index]

#--------------------------------------------------------------------------------------------------
