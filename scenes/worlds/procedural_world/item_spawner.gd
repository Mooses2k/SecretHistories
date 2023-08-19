tool
class_name ItemSpawner
extends Spawner

# This is a tool so that `_min_loot` and `_max_loot` setters can act as data validators when
# changing values in the editor

const ITEM_POSITION_OFFSET = Vector3(0.75, 1.0, 0.75)

var free_cell = 0

var _rng := RandomNumberGenerator.new()
var _used_cell_indexes := []

### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if Engine.editor_hint:
		return

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

# Parent GameWorld script connects here.
func _on_game_world_generation_finished():
	var setting_generation_seed = GameManager.game.local_settings.get_setting("World Seed")
	if setting_generation_seed is int:
		_rng.seed = setting_generation_seed
	
	var data := owner.world_data as WorldData
	_spawn_initial_settings_items(data)
	_spawn_world_data_objects(data)
	
	has_finished_spawning = true
	emit_signal("spawning_finished")


func _spawn_world_data_objects(data: WorldData) -> void:
	var objects_to_spawn := data.get_objects_to_spawn()
	for cell_index in objects_to_spawn:
		var spawn_data := objects_to_spawn[cell_index] as SpawnData
		spawn_data.spawn_item_in(owner)


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
	return true   # TODO: Unrecahable code, probably should be indented one tab further
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

### -----------------------------------------------------------------------------------------------
