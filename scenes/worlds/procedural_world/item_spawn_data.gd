@tool
class_name ItemSpawnData
extends SpawnData

## SpawnData for Items.

#- Member Variables and Dependencies --------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const ITEM_CENTER_POSITION_OFFSET = Vector3(0.75, 1.0, 0.75)

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

var _has_spawned := false

#--------------------------------------------------------------------------------------------------


#- Built-in Virtual Overrides ---------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------


#- Public Methods ---------------------------------------------------------------------------------

## Spawns all items from this ItemSpawnData and returns and Array of Spawned nodes.
func spawn_in(node: Node, should_log := false) -> Array[Node]:
	var spawned_objects: Array[Node] = []
	if scene_path.is_empty():
		return spawned_objects
	
	if _has_spawned:
		return spawned_objects
	
	var item_scene : PackedScene = load(scene_path)
	if not is_instance_valid(item_scene):
		assert(is_instance_valid(item_scene), "Could not find or load scene_path: %s"%[scene_path])
		return spawned_objects
	
	for index in amount:
		var item = item_scene.instantiate()
		
		if item is Node3D:
			item.transform = _transforms[index]
		
		_set_custom_properties_on_loaded_scene(index, item)
		
		node.add_child(item, true)
		
		# Having this here instead of ready() function of light fixes blueprint SHOULD_PLACE candle emissive material bug
		if item is CandleItem or item is CandelabraItem:
			item.light()
		
		if should_log:
			print("item spawned: %s | at: %s | rotated by: %s"%[
					scene_path, _transforms[index].origin, _transforms[index].basis.get_euler()
			])
	
	_has_spawned = true
	return spawned_objects

#--------------------------------------------------------------------------------------------------


#- Private Methods --------------------------------------------------------------------------------

func _get_center_offset() -> Vector3:
	return ITEM_CENTER_POSITION_OFFSET

#--------------------------------------------------------------------------------------------------


#- Signal Callbacks -------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------
