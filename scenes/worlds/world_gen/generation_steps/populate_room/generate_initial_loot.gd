@tool
# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

@export var _loot_list_resource: Resource = null
@export var _min_loot := 5: set = _set_min_loot
@export var _max_loot := 10: set = _set_max_loot
@export var _min_radius_multiplier := 0.1
@export var _max_radius_multiplier := 0.3

var _rng := RandomNumberGenerator.new()

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		return

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _execute_step(data: WorldData, gen_data : Dictionary, generation_seed : int):
	if Engine.is_editor_hint():
		return
	elif _loot_list_resource == null or not _loot_list_resource is ObjectSpawnList:
		push_error("No resource, or invalid resource, on _loot_list_resource property")
		return
	
	_rng.seed = generation_seed
	
	# TODO: this is probably where we'll set the DLvl match for different floor-loot lists
	_generate_initial_loot_spawn_data(data, _loot_list_resource)


func _generate_initial_loot_spawn_data(data: WorldData, loot_list: ObjectSpawnList) -> void:
	var draw_amount := _rng.randi_range(_min_loot, (_max_loot * -GameManager.game.current_floor_level))
	print("Spawning this many non-bone items on ground: ", draw_amount)
	var possible_cells := data.get_cells_for(data.CellType.ROOM)
	possible_cells = _remove_used_cells_from(possible_cells, data)
	
	for _i in draw_amount:
		var spawn_data := loot_list.get_random_spawn_data(_rng)
		
		if possible_cells.is_empty():
			return
		
		var lucky_index = _rng.randi() % possible_cells.size()
		var cell_index := possible_cells[lucky_index] as int
		possible_cells.remove_at(lucky_index)
		
		var cell_position := data.get_local_cell_position(cell_index)
		var cell_radius := data.CELL_SIZE * 0.5
		spawn_data.set_random_position_in_cell(
				_rng, 
				cell_position, 
				cell_radius * _min_radius_multiplier, 
				cell_radius * _max_radius_multiplier
		)
		
		data.set_object_spawn_data_to_cell(cell_index, spawn_data)


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


func _set_min_loot(value: int) -> void:
	_min_loot = clamp(value, 0, _max_loot)


func _set_max_loot(value: int) -> void:
	_max_loot = max(value, _min_loot)

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
