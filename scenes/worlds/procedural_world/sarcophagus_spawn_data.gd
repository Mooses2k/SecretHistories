class_name SarcophagusSpawnData
extends ItemSpawnData

## Write your doc string for this file here

#- Member Variables and Dependencies --------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const COMET_SHARD_PATH = "res://scenes/objects/pickable_items/equipment/strange_devices/comet_shard/comet_shard.tscn"

# These comes from the Marker3D nodes inside the sarcophagus base scene and on the 
# lid scenes. They'll need to be updated if there is any change on the Marker3D nodes
# on those scenes.
const MAX_SPAWN_POSITIONS_INSIDE = 15
const MAX_SPAWN_POSITIONS_ON_LID = 11

#--- public variables - order: export > normal var > onready --------------------------------------

var lid_type: Sarcophagus.PossibleLids = Sarcophagus.PossibleLids.EMPTY
# Can't use WorldData.Directions here because center sarcos are signalled as -1
var wall_direction: int = -1

#--- private variables - order: export > normal var > onready -------------------------------------

var _inside_positions := range(MAX_SPAWN_POSITIONS_INSIDE)
var _lid_position := range(MAX_SPAWN_POSITIONS_ON_LID)

# Dictionary of SpawnData for inside the sarcophagus in the format:
# { index_of_marker3D_to_use_inside_sarco: ItemSpawnData }
var _inside_spawns := {}
# Dictionary of SpawnData in the same format above
var _lid_spawns := {}

#--------------------------------------------------------------------------------------------------


#- Built-in Virtual Overrides ---------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------


#- Public Methods ---------------------------------------------------------------------------------

func set_random_lid_type(rng: RandomNumberGenerator) -> void:
	lid_type = rng.randi() % Sarcophagus.PossibleLids.keys().size()


func set_inside_spawns(
		amount: int, 
		possible_items: ObjectSpawnList, 
		rng: RandomNumberGenerator, 
		has_shard := false
) -> void:
	if amount > _inside_positions.size():
		amount = _inside_positions.size()
		push_warning("Trying to spawn more items than sarco inside can hold.")
	
	var has_spawned_shard := false
	for index in amount:
		var position_index := rng.randi() % _inside_positions.size()
		if has_spawned_shard and not has_spawned_shard:
			var spawn_data := ItemSpawnData.new()
			spawn_data.scene_path = COMET_SHARD_PATH
			_inside_spawns[position_index] = spawn_data
		else:
			_inside_spawns[position_index] = possible_items.get_random_spawn_data(rng)
		_inside_positions.remove_at(position_index)


func set_lid_spawns(
	amount: int,
	possible_items: ObjectSpawnList,
	rng: RandomNumberGenerator
) -> void:
	if amount > _lid_position.size():
		amount = _lid_position.size()
		push_warning("Trying to spawn more items than sarco lid can hold.")
	
	for index in amount:
		var position_index := rng.randi() % _lid_position.size()
		_lid_spawns[position_index] = possible_items.get_random_spawn_data(rng)
		_lid_position.remove_at(position_index)


## Spawns all items from this ItemSpawnData and returns and Array of Spawned nodes.
func spawn_in(node: Node, should_log := false) -> Array[Node]:
	var spawned_objects: Array[Node] = []
	if _has_spawned:
		return spawned_objects
	
	var item_scene : PackedScene = load(scene_path)
	if not is_instance_valid(item_scene):
		assert(is_instance_valid(item_scene), "Could not find or load scene_path: %s"%[scene_path])
		return spawned_objects
	
	for index in amount:
		var sarco := item_scene.instantiate() as Sarcophagus
		sarco.transform = _transforms[index]
		sarco.current_lid = lid_type
		sarco.wall_direction = wall_direction
		sarco.inside_spawnable_items = _inside_spawns
		sarco.lid_spawnable_items = _lid_spawns
		
		var custom_properties := _custom_properties[index] as Dictionary
		for key in custom_properties:
			sarco.set(key, custom_properties[key])
		
		node.add_child(sarco, true)
		
		if should_log:
			print("item spawned: %s | at: %s | rotated by: %s"%[
					scene_path, _transforms[index].origin, _transforms[index].basis.get_euler()
			])
	
	_has_spawned = true
	return spawned_objects

#--------------------------------------------------------------------------------------------------


#- Private Methods --------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------


#- Signal Callbacks -------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------
