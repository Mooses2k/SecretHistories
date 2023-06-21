# Write your doc string for this file here
tool
class_name CharacterSpawnData
extends SpawnData

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const CHARACTER_CENTER_POSITION_OFFSER = Vector3(0.75, 0.0, 0.75)

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _to_string() -> String:
	var msg := "[CharacterSpawnData:%s | amount: %s scene_path: %s tranforms: %s]"%[
			get_instance_id(), amount, scene_path, _transforms
	]
	return msg

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func spawn_character_in(node: Node, should_log := false) -> Spatial:
	var character = load(scene_path).instance() as Spatial
	if character == null:
		push_error("scene_path is not a Spatial: %s"%[scene_path])
		return character
	
	character.transform = _transforms.front()
	node.add_child(character, true)
	
	if should_log:
		print("Character spawned: %s at: %s"%[character, character.translation])
	
	return character

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _set_amount(value: int) -> void:
	if value != 1:
		value = 1
		push_warning("Can't spawn more than 1 character per cell")
	
	._set_amount(value)


func _get_center_offset() -> Vector3:
	return CHARACTER_CENTER_POSITION_OFFSER

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
