tool
extends Node


# This is a tool so that `_min_loot` and `_max_loot` setters can act as data validators when
# changing values in the editor

const ITEM_POSITION_OFFSET = Vector3(0.75, 1.0, 0.75)

# TODO: I've put this here like this just to be able to test the changes to spawning character 
# in a starting room. It will probably be best to move this to the world settings, with a setting
# for "initial light" separate from the equipments settings, and wich gives as choice one of the
# available lights. Until then, just change this export var to change the initial light available
# for the player
export var starting_light: PackedScene

var free_cell = 0

var _rng := RandomNumberGenerator.new()
var _used_cell_indexes := []


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if Engine.editor_hint:
		return

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _on_ProceduralWorld_generation_finished() -> void:
	var setting_generation_seed = GameManager.game.local_settings.get_setting("World Seed")
	if setting_generation_seed is int:
		_rng.seed = setting_generation_seed
	
	var data := owner.world_data as WorldData
	_spawn_starting_light(data)
	_spawn_initial_settings_items(data)
	_spawn_world_data_objects(data)


func _spawn_world_data_objects(data: WorldData) -> void:
	var objects_to_spawn := data.get_objects_to_spawn()
	for cell_index in objects_to_spawn:
		var spawn_data := objects_to_spawn[cell_index] as SpawnData
		for _i in spawn_data.amount:
			spawn_data.spawn_item_in(owner)


# This calculates the center position of the cell and then tries to find a random position 
# around it
func _get_random_position_in_cell(
		cell_position: Vector3, min_radius: float, max_radius: float, angle: float
) -> Vector3:
	var center_position := cell_position + ITEM_POSITION_OFFSET
	
	var radius := _rng.randf_range(min_radius, max_radius)
	var random_direction := Vector3(cos(angle), 0.0, sin(angle)).normalized()
	var polar_coordinate := random_direction * radius
	
	var value := center_position + polar_coordinate
	return value


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
				var cell_pos = data.get_local_cell_position(free_cell) + ITEM_POSITION_OFFSET
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


# Angle is in radians
func _spawn_item(scene_path: String, position: Vector3, angle := 0.0) -> void:
	var item
	var item_scene : PackedScene = load(scene_path)
	item = item_scene.instance()
	if item is Spatial:
		(item as Spatial).translation = position
		(item as Spatial).rotate_y(angle)
	
	owner.add_child(item)
#	print("item spawned: %s | at: %s | rotated y by: %s"%[scene_path, position, angle])


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
	
	var starting_room := data.get_starting_room_data()
	var starting_cells = starting_room.cell_indexes
	if data.is_spawn_position_valid():
		var player_index := data.get_player_spawn_position_as_index()
		starting_cells.erase(player_index)
	
	var random_cell_index := _rng.randi() % starting_cells.size() as int
	var spawn_cell = starting_cells[random_cell_index]
	_used_cell_indexes.append(spawn_cell)
	
	var local_pos = data.get_local_cell_position(spawn_cell) + ITEM_POSITION_OFFSET
	_spawn_item(starting_light.resource_path, local_pos)

### -----------------------------------------------------------------------------------------------
