class_name GenerationManager
extends Node


@export var world_size_x : int = 40
@export var world_size_z : int = 40
@export var generation_seed : int = 0

signal generation_started(data, gen_data)
signal step_finished(data)
signal generation_finished(data)


func generate(is_last_floor: bool) -> WorldData:
	if GameManager.world_gen_rng == null:
		GameManager.world_gen_rng = RandomNumberGenerator.new()
		var setting_generation_seed = GameManager.game.local_settings.get_setting("World Seed")
		if setting_generation_seed is int:
			generation_seed = setting_generation_seed
		print("Generation Seed: %s"%[generation_seed])
		GameManager.world_gen_rng.seed = generation_seed
	 
	# Set global random seed, so rng is consistent even
	# when it isn't possible to use the world_gen_seed directly
	# (for example, when using Array.shuffle())
	seed(GameManager.world_gen_rng.randi())
	
	var data : WorldData = WorldData.new()
	data.resize(world_size_x, world_size_z)
	
	var gen_data = Dictionary()
	gen_data[GenerationStep.LAST_FLOOR_KEY] = is_last_floor
	emit_signal("generation_started", data, gen_data)
	for _step in get_children():
		var step = _step as GenerationStep
		if step:
			var start = Time.get_ticks_usec()
			step.execute_step(data, gen_data, GameManager.world_gen_rng.randi())
			var end = Time.get_ticks_usec()
			print("Step took ", end - start, " usec")
			emit_signal("step_finished", data, gen_data)
	emit_signal("generation_finished", data, gen_data)
	return data
