@tool
# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

@export var room_rect := Rect2(1,1,4,4): set = _set_room_rect

var room_purpose := 0
var doorways := {
		WorldData.Direction.NORTH: -1,
		WorldData.Direction.EAST: -1,
		WorldData.Direction.SOUTH: -1,
		WorldData.Direction.WEST: -1,
}

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	data.fill_room_data(room_rect, room_purpose)
	gen_data[ROOM_ARRAY_KEY] = [room_rect]
	var current_room := data.get_rooms_of_type(room_purpose).back() as RoomData
	
	for direction in doorways:
		if doorways[direction] == -1:
			continue
		
		var starting_wall_cell := Vector2.ZERO
		var offset := Vector2.ZERO
		var poisition_range = [doorways[direction], doorways[direction] + 1]
		var x_range := []
		var y_range := []
		match direction:
			data.Direction.NORTH:
				starting_wall_cell = room_rect.position
				x_range = poisition_range
				offset = Vector2(0, -1)
			data.Direction.EAST:
				starting_wall_cell = Vector2(room_rect.end.x-1, room_rect.position.y)
				y_range = poisition_range
				offset = Vector2(1, 0)
			data.Direction.SOUTH:
				starting_wall_cell = Vector2(room_rect.position.x, room_rect.end.y-1)
				x_range = poisition_range
				offset = Vector2(0, 1)
			data.Direction.WEST:
				starting_wall_cell = room_rect.position
				y_range = poisition_range
				offset = Vector2(-1, 0)
		
		var door_direction := data.direction_inverse(direction)
		if not x_range.is_empty():
			for x in x_range:
				var room_cell := starting_wall_cell + Vector2(x, 0)
				var door_cell := room_cell + offset
				var room_index := data.get_cell_index_from_int_position(room_cell.x, room_cell.y)
				var door_index := data.get_cell_index_from_int_position(door_cell.x, door_cell.y)
				data.set_cell_type(door_index, data.CellType.DOOR)
				_set_doorways_meta(data, room_index, door_direction)
				_set_doorways_meta(data, door_index, door_direction)
		
		if not y_range.is_empty():
			for y in y_range:
				var room_cell := starting_wall_cell + Vector2(0, y)
				var door_cell := room_cell + offset
				var room_index := data.get_cell_index_from_int_position(room_cell.x, room_cell.y)
				var door_index := data.get_cell_index_from_int_position(door_cell.x, door_cell.y)
				data.set_cell_type(door_index, data.CellType.DOOR)
				_set_doorways_meta(data, room_index, door_direction)
				_set_doorways_meta(data, door_index, door_direction)


func _add_door_direction(data : WorldData, cell : int, value : int):
	if not data.has_cell_meta(cell, data.CellMetaKeys.META_DOOR_DIRECTIONS):
		data.set_cell_meta(cell, data.CellMetaKeys.META_DOOR_DIRECTIONS, Array())
	if not data.get_cell_meta(cell, data.CellMetaKeys.META_DOOR_DIRECTIONS).has(value):
		data.get_cell_meta(cell, data.CellMetaKeys.META_DOOR_DIRECTIONS).push_back(value)


func _set_doorways_meta(data: WorldData, cell_index: int, direction: int) -> void:
	if data.get_cell_type(cell_index) == data.CellType.ROOM:
		var room_data := data.get_cell_meta(cell_index, data.CellMetaKeys.META_ROOM_DATA) as RoomData
		room_data.set_doorway_cell(cell_index, data.direction_inverse(direction))
	elif data.get_cell_type(cell_index) == data.CellType.DOOR:
		_add_door_direction(data, cell_index, direction)


func _set_room_rect(value: Rect2) -> void:
	room_rect = value
	notify_property_list_changed()

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

###################################################################################################
# Editor Methods ##################################################################################
###################################################################################################

### Custom Inspector built in functions -----------------------------------------------------------

const DOORWAY_HINT = "doorway_"
func _get_property_list() -> Array:
	var properties: = []
	
	var enum_hint := (RoomData.OriginalPurpose.keys() as ",".join(PackedStringArray))
	properties.append({
		name = "room_purpose",
		type = TYPE_INT,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		hint = PROPERTY_HINT_ENUM,
		hint_string = enum_hint
	})
	
	properties.append({
		name = "doorways",
		type = TYPE_DICTIONARY,
		usage = PROPERTY_USAGE_STORAGE,
	})
	
	properties.append({
		name = "Doorways Starting Position",
		type = TYPE_NIL,
		usage = PROPERTY_USAGE_GROUP,
		hint_string = DOORWAY_HINT
	})
	
	for direction in doorways:
		var hint_string := "-1,%s,1"%[room_rect.size.x - 2]
		if direction == WorldData.Direction.EAST or direction == WorldData.Direction.WEST:
			hint_string = "-1,%s,1"%[room_rect.size.y - 2]
		properties.append({
			name = "%s%s"%[DOORWAY_HINT, WorldData.Direction.keys()[direction]],
			type = TYPE_INT,
			usage = PROPERTY_USAGE_EDITOR,
			hint = PROPERTY_HINT_RANGE,
			hint_string = hint_string
		})
	
	return properties


func _set(property: String, value) -> bool:
	var has_handled := true
	
	if property.begins_with(DOORWAY_HINT):
		var key = property.replace(DOORWAY_HINT, "")
		var direction = WorldData.Direction[key]
		doorways[direction] = value
	else:
		has_handled = false
	
	return has_handled


func _get(property: String):
	var value = null
	
	if property.begins_with(DOORWAY_HINT):
		var key = property.replace(DOORWAY_HINT, "")
		var direction = WorldData.Direction[key]
		value = doorways[direction]
	
	return value

### -----------------------------------------------------------------------------------------------
