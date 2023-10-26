# Write your doc string for this file here
tool
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

export(String, FILE, "*.tscn") var _character_scene_path := ""
export var _max_count = 5

var _density_by_type := {
	WorldData.CellType.ROOM: 0.025,
	WorldData.CellType.CORRIDOR: 0.0,
	WorldData.CellType.HALL: 0.0,
}

var _rng := RandomNumberGenerator.new()

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready():
	if Engine.editor_hint:
		return

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	_rng.seed = generation_seed
	
	var valid_cells := _get_valid_cells(data)
	
	var count = 0
	for cell_index in valid_cells:
		if count >= _max_count:
			break
		
		var cell_type = data.get_cell_type(cell_index)
		if _rng.randf() < _density_by_type[cell_type]:
			count += 1
			var local_position := data.get_local_cell_position(cell_index)
			var spawn_data := CharacterSpawnData.new()
			spawn_data.scene_path = _character_scene_path
			spawn_data.set_center_position_in_cell(local_position)
			data.set_character_spawn_data_to_cell(cell_index, spawn_data)


func _get_valid_cells(data: WorldData) -> Array:
	var valid_cells := []
	for type in _density_by_type.keys():
		valid_cells.append_array(data.get_cells_for(type))
	valid_cells.sort()
	
	_remove_used_cells_from(valid_cells, data)
	return valid_cells



func _remove_used_cells_from(p_array: Array, data: WorldData) -> Array:
	for cell_index in data._objects_to_spawn.keys():
		p_array.erase(cell_index)
	
	if data.is_spawn_position_valid():
		var player_cells := [
				data.get_player_spawn_position_as_index(RoomData.OriginalPurpose.UP_STAIRCASE),
				data.get_player_spawn_position_as_index(RoomData.OriginalPurpose.DOWN_STAIRCASE),
		]
		for player_cell in player_cells:
			p_array.erase(player_cell)
	
	return p_array

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

###################################################################################################
### Editor Code ###################################################################################
###################################################################################################

const GROUP_PREFIX_DENSITY = "density_"
const PERCENT_CONVERSION = 100.0


func _get_property_list() -> Array:
	var properties := [
		{
			name = "_density_by_type",
			type = TYPE_DICTIONARY,
			usage = PROPERTY_USAGE_STORAGE,
		},
		{
			name = "Density by Cell Type",
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_GROUP,
			hint_string = GROUP_PREFIX_DENSITY
		},
	]
	
	for type in ["room", "corridor", "hall"]:
		properties.append({
			name = GROUP_PREFIX_DENSITY + type,
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_EDITOR,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0,100.0,0.05"
		})
	
	return properties


func _get(property: String):
	var value
	
	if property.begins_with(GROUP_PREFIX_DENSITY):
		var type := property.replace(GROUP_PREFIX_DENSITY, "")
		match type:
			"room":
				value = _density_by_type[WorldData.CellType.ROOM] * PERCENT_CONVERSION
			"corridor":
				value = _density_by_type[WorldData.CellType.CORRIDOR] * PERCENT_CONVERSION
			"hall":
				value = _density_by_type[WorldData.CellType.HALL] * PERCENT_CONVERSION
			_:
				push_error("Unindentified density type: %s"%[type])
	
	return value


func _set(property: String, value) -> bool:
	var has_handled = false
	
	if property.begins_with(GROUP_PREFIX_DENSITY):
		var type := property.replace(GROUP_PREFIX_DENSITY, "")
		var index := -1
		match type:
			"room":
				index = WorldData.CellType.ROOM
			"corridor":
				index = WorldData.CellType.CORRIDOR
			"hall":
				index = WorldData.CellType.HALL
			_:
				push_error("Unindentified density type: %s"%[type])
		
		if index > -1:
			var final_value = value / PERCENT_CONVERSION
			_density_by_type[index] = final_value
			has_handled = true
	
	return has_handled

### END of Editor Code ############################################################################
