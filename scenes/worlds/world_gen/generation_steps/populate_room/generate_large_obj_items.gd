# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

var _rng := RandomNumberGenerator.new()

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	_rng.seed = generation_seed
	
	for child in get_children():
		if child is GenerationStep:
			child.execute_step(data, gen_data, _rng.randi())
		else:
			push_error("Node (%s) is not GenerationStep and is inside GenerationGroup. Path:%s"%[
					child, (child as Node).get_path()
			])

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
