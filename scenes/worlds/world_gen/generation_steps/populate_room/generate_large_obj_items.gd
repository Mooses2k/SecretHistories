# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

export var _sarco_spawn_list_resource: Resource = null
export var _min_item := 5 setget _set_min_item
export var _max_item := 10 setget _set_max_item

var _rng := RandomNumberGenerator.new()

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	_rng.seed = generation_seed
	var draw_amount := _rng.randi_range(_min_item, _max_item)
	var temp_item_list : PoolStringArray
	for _i in draw_amount:
		temp_item_list.append((_sarco_spawn_list_resource.get_random_spawn_data(_rng)).scene_path)
		
	data.set_sarco_item_list(temp_item_list)
	
	for child in get_children():
		if child is GenerationStep:
			child.execute_step(data, gen_data, generation_seed)
		else:
			push_error("Node (%s) is not GenerationStep and is inside GenerationGroup. Path:%s"%[
					child, (child as Node).get_path()
			])


func _set_min_item(value: int) -> void:
	_min_item = clamp(value, 0, _max_item)


func _set_max_item(value: int) -> void:
	_max_item = max(value, _min_item)

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
