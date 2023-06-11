class_name GenerationManager
extends Node


export var world_size_x : int = 40
export var world_size_z : int = 40
export var generation_seed : int = 0

signal generation_started(data, gen_data)
signal step_finished(data)
signal generation_finished(data)


func generate() -> WorldData:
	var setting_generation_seed = GameManager.game.local_settings.get_setting("World Seed")
	if setting_generation_seed is int:
		generation_seed = setting_generation_seed
		print("Generation Seed: %s"%[generation_seed])
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
