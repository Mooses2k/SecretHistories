extends Node

const ITEM_POSITION_OFFSET = Vector3(0.75, 1.0, 0.75)

# TODO: I've put this here like this just to be able to test the changes to spawning character 
# in a starting room. It will probably be best to move this to the world settings, with a setting
# for "initial light" separate from the equipments settings, and wich gives as choice one of the
# available lights. Until then, just change this export var to change the initial light available
# for the player
export var starting_light: PackedScene

var free_cell = 0

var _used_cell_indexes := []

### Private Methods --------------------------------------------------------------------------------

func _on_ProceduralWorld_generation_finished() -> void:
	var data := owner.world_data as WorldData
	_spawn_starting_light(data)
	_spawn_initial_settings_items(data)


func _spawn_initial_settings_items(data : WorldData):
	var settings : SettingsClass = GameManager.game.local_settings
	
	_get_next_free_cell(data)
	for s in settings.get_settings_list():
		var g = settings.get_setting_group(s)
		var amount = settings.get_setting(s)
		
		if g == "Equipment":
			for i in amount:
				if not _get_next_free_cell(data):
					return
				
				_used_cell_indexes.append(free_cell)
				var cell_pos = data.get_local_cell_position(free_cell)
				_spawn_item(s, cell_pos)
		elif g == "Tiny Items":
			if amount == 0:
				continue
			if not _get_next_free_cell(data):
				return
			
			_used_cell_indexes.append(free_cell)
			var pos = data.get_local_cell_position(free_cell) + ITEM_POSITION_OFFSET
			_spawn_tiny_item(s, amount, pos)


func _get_next_free_cell(data : WorldData) -> bool:
	free_cell += 1
	while data.get_cell_type(free_cell) == data.CellType.EMPTY and free_cell < data.cell_count:
		free_cell += 1
	return true
	if free_cell >= data.cell_count:
		return false


func _spawn_item(scene_path: String, cell_pos: Vector3) -> void:
	var pos = cell_pos + ITEM_POSITION_OFFSET
	
	var item
	var item_scene : PackedScene = load(scene_path)
	item = item_scene.instance()
	(item as Spatial).translation = pos
	
	owner.add_child(item)


func _spawn_tiny_item(item_data_path: String, amount: int, position: Vector3) -> void:
	var tiny_item_scene = preload("res://scenes/objects/pickable_items/tiny/_tiny_item.tscn")
	var item : TinyItem = tiny_item_scene.instance()
	item.amount = amount
	item.item_data = load(item_data_path)
	item.translation = position
	owner.add_child(item)


func _spawn_starting_light(data : WorldData) -> void:
	if starting_light == null:
		return
	
	var starting_cells = data.get_cells_for(data.CellType.STARTING_ROOM)
	if data.is_spawn_position_valid():
		var player_index := data.get_player_spawn_position_as_index()
		starting_cells.erase(player_index)
	
	var random_cell_index := randi() % starting_cells.size() as int
	var spawn_cell = starting_cells[random_cell_index]
	_used_cell_indexes.append(spawn_cell)
	print("light spawned at: %s"%[data.get_int_position_from_cell_index(spawn_cell)])
	
	var local_pos = data.get_local_cell_position(spawn_cell)
	_spawn_item(starting_light.resource_path, local_pos)

### ------------------------------------------------------------------------------------------------
