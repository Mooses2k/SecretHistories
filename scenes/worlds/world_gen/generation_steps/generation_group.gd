# Acts as a Group of GenerationSteps, it will execute all of it's children before moving on
class_name GenerationGroup
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	for child in get_children():
		if child is GenerationStep:
			child.execute_step(data, gen_data, generation_seed)
		else:
			push_error("Node (%s) is not GenerationStep and is inside GenerationGroup. Path3D:%s"%[
					child, (child as Node).get_path()
			])

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
