# Write your doc string for this file here
extends GenerationManager

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

export(int, -5, -1, -1) var dungeon_level := -1

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func generate(is_last_floor: bool) -> WorldData:
	if GameManager.world_gen_rng == null:
		GameManager.world_gen_rng = RandomNumberGenerator.new()
		print("Generation Seed: %s"%[generation_seed])
		GameManager.world_gen_rng.seed = generation_seed
	
	if dungeon_level < -1:
		for _i in range(-1, dungeon_level, -1):
			for _step in get_children():
				GameManager.world_gen_rng.randi()
	
	var data : WorldData = WorldData.new()
	data.resize(world_size_x, world_size_z)
	
	var gen_data = Dictionary()
	gen_data[GenerationStep.LAST_FLOOR_KEY] = is_last_floor
	emit_signal("generation_started", data, gen_data)
	for _step in get_children():
		var step = _step as GenerationStep
		if step:
			var start = OS.get_ticks_usec()
			step.execute_step(data, gen_data, GameManager.world_gen_rng.randi())
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
