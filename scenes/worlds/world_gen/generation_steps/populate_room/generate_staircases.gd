# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const PATH_UP_STAIRCASE = "res://scenes/objects/large_objects/staircases/staircase_up.tscn"
const PATH_DOWN_STAIRCASE = "res://scenes/objects/large_objects/staircases/staircase_down.tscn"

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	var staircase_rooms := []
	staircase_rooms.append_array(data.get_rooms_of_type(RoomData.OriginalPurpose.UP_STAIRCASE))
	staircase_rooms.append_array(data.get_rooms_of_type(RoomData.OriginalPurpose.DOWN_STAIRCASE))
	for room in staircase_rooms:
		_populate_staircase(room, data)


func _populate_staircase(room: RoomData, world_data: WorldData) -> void:
	var spawn_data := SpawnData.new()
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
	elif door_directions.empty():
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
	
	for index in room.cell_indexes:
		world_data.set_object_spawn_data_to_cell(index, spawn_data)

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
