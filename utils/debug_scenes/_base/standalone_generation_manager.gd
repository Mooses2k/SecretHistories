# Write your doc string for this file here
extends GenerationManager

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

func generate() -> WorldData:
	var data : WorldData = WorldData.new()
	data.resize(world_size_x, world_size_z)
	
	var gen_data = Dictionary()
	var random = RandomNumberGenerator.new()
	random.seed = generation_seed
	emit_signal("generation_started", data, gen_data)
	for _step in get_children():
		var step = _step as GenerationStep
		if step:
			var start = OS.get_ticks_usec()
			step.execute_step(data, gen_data, random.randi())
			var end = OS.get_ticks_usec()
			print("Step took ", end - start, " usec")
			emit_signal("step_finished", data, gen_data)
	emit_signal("generation_finished", data, gen_data)
	return data

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
