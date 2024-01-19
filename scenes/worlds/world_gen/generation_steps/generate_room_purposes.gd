@tool
# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

var purpose_resources := []

#--- private variables - order: export > normal var > onready -------------------------------------

var _rng := RandomNumberGenerator.new()

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, _gen_data : Dictionary, generation_seed : int):
	_rng.seed = generation_seed
	for value in purpose_resources:
		var purpose = value as RoomPurpose
		if purpose == null:
			continue

		var valid_rooms := _get_valid_rooms(data, purpose)
		if valid_rooms.is_empty():
			continue

		var chosen_rooms := _get_chosen_rooms(purpose, valid_rooms)
		for c_value in chosen_rooms:
			var room := c_value as RoomData
			room.type = purpose.purpose_id
			data.change_room_type(RoomData.OriginalPurpose.EMPTY, room.type, room)
	
	print("\n-- data.rooms:")
	for key in data.rooms:
		print("\t%s: %s"%[RoomData.OriginalPurpose.keys()[key], data.rooms[key].size()])
	print("-- END OF data.rooms\n")

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

func _get_valid_rooms(data: WorldData, purpose: RoomPurpose) -> Array:
	var valid_rooms := []
	
	var empty_rooms := data.get_rooms_of_type(RoomData.OriginalPurpose.EMPTY)
	for value in empty_rooms:
		var empty_room := value as RoomData
		if purpose.is_compatible(empty_room):
			valid_rooms.append(empty_room)
	
	return valid_rooms


func _get_chosen_rooms(purpose: RoomPurpose, valid_rooms: Array) -> Array:
	var chosen_rooms := []
	
	if purpose.max_amount > 0 and valid_rooms.size() > purpose.max_amount:
		for _index in purpose.max_amount:
				var chosen_index := _rng.randi() % valid_rooms.size()
				var chosen_room := valid_rooms[chosen_index] as RoomData
				chosen_rooms.append(chosen_room)
				valid_rooms.remove_at(chosen_index)
	else:
		chosen_rooms = valid_rooms
	
	return chosen_rooms

### -----------------------------------------------------------------------------------------------

###################################################################################################
# Editor Methods ##################################################################################
###################################################################################################

### Custom Inspector built in functions -----------------------------------------------------------

func _get_property_list() -> Array:
	var properties: = []
	
	properties.append({
		name = "purpose_resources",
		type = TYPE_ARRAY,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		hint = PROPERTY_HINT_RESOURCE_TYPE,
		hint_string = "%s/%s:Resource"%[TYPE_OBJECT, TYPE_OBJECT]
	})
	
	return properties

### -----------------------------------------------------------------------------------------------
