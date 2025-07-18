extends GenerationStep

## Write your doc string for this file here

#- Member Variables and Dependencies --------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const TINY_ITEM_PATH = "res://scenes/objects/pickable_items/tiny/_tiny_item.tscn"

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

#--------------------------------------------------------------------------------------------------


#- Built-in Virtual Overrides ---------------------------------------------------------------------

func _ready() -> void:
	pass

#--------------------------------------------------------------------------------------------------


#- Public Methods ---------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------


#- Private Methods --------------------------------------------------------------------------------

func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int) -> void:
	if GameManager.game.current_floor_level != Game.HIGHEST_FLOOR_LEVEL:
		return
	
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = generation_seed
	
	var items_to_spawn := _get_all_spawndata()
	if items_to_spawn.is_empty():
		return
	
	# Get walkable Cells close to the player to spread the the generated spawn data on.
	var player_spawn_index: int = _get_player_spawn_cell_index(data)
	if player_spawn_index == -1:
		return
	
	var valid_cells_by_distance := _get_valid_cells_by_distance(player_spawn_index, data, gen_data)
	for dict in valid_cells_by_distance:
		var spawn_data: SpawnData = null
		if not items_to_spawn.is_empty():
			spawn_data = items_to_spawn.pop_back() as ItemSpawnData
		
		if spawn_data == null:
			break
		
		var cell_position := data.get_local_cell_position(dict.cell_index)
		
		# Use this line if you want it centered instead of random position in cell
		#spawn_data.set_center_position_in_cell(cell_position)
		spawn_data.set_random_position_in_cell(random, cell_position, 0.0, data.CELL_SIZE/4.0)
		
		# This helps debugs any distance problems, but leaving it disabled.
		#print("spawning at %s with a distance of %s: \n%s"%[dict.cell_index, dict.distance.size(), spawn_data])
		data.set_object_spawn_data_to_cell(dict.cell_index, spawn_data)
	
	if not items_to_spawn.is_empty():
		push_warning("There wasn't enough space to spawn initial settings items!")
	pass


func _get_all_spawndata() -> Array[ItemSpawnData]:
	var items_to_spawn: Array[ItemSpawnData] = []
	
	var settings : SettingsClass = GameManager.game.local_settings
	for resource_path in settings.get_settings_list():
		var group: String = settings.get_setting_group(resource_path)
		var amount: int = settings.get_setting(resource_path)
		if group == "Equipment" and amount > 0:
			var spawn_data := ItemSpawnData.new()
			spawn_data.scene_path = resource_path
			spawn_data.amount = amount
			items_to_spawn.append(spawn_data)
		elif group == "Tiny Items" and amount > 0:
			var spawn_data := ItemSpawnData.new()
			spawn_data.scene_path = TINY_ITEM_PATH
			spawn_data.set_custom_property("amount", amount)
			spawn_data.set_custom_property("item_data", load(resource_path))
			items_to_spawn.append(spawn_data)
	
	return items_to_spawn


func _get_player_spawn_cell_index(data: WorldData) -> int:
	var value: int = -1
	
	var stairs_entrances: Array = \
			data.player_spawn_positions[RoomData.OriginalPurpose.UP_STAIRCASE].keys()
	if stairs_entrances.is_empty():
		var error_msg := "There should be at least one down stairs defined at this point. Aborting."
		assert(not stairs_entrances.is_empty(), error_msg)
		return value
	
	value = stairs_entrances[0]
	return value


func _get_valid_cells_by_distance(player_spawn_index: int, data: WorldData, gen_data: Dictionary) -> Array:
	var value: Array = []
	
	var valid_cells: Array[int] = []
	var astar = gen_data[KEY_ASTAR] as ManhattanAStar2D
	for type in [data.CellType.ROOM, data.CellType.CORRIDOR, data.CellType.HALL]:
		valid_cells.append_array(data.get_cells_for(type))
	
	valid_cells = data.remove_used_cells_from(valid_cells)
	# This will return an array of dictionaries but map doesn't allow to return typed arrays
	value = valid_cells.map(_map_by_distance_to_player_spawn.bind(
			player_spawn_index,
			astar
	))
	value.sort_custom(_sort_by_distance_to_player_spawn)
	
	return value


func _map_by_distance_to_player_spawn(
		cell_index: int, 
		spawn_index: int, 
		astar: ManhattanAStar2D
) -> Dictionary:
	var path := astar.get_point_path(spawn_index, cell_index)
	assert(path.size() > 0, "Path should never be 0 or -1, that means cell is unreachable.")
	
	var value := {
			"cell_index": cell_index,
			"distance": path
	}
	
	return value


func _sort_by_distance_to_player_spawn(dict_a: Dictionary, dict_b: Dictionary) -> bool:
	return dict_a.distance.size() < dict_b.distance.size()


#--------------------------------------------------------------------------------------------------


#- Signal Callbacks -------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------
