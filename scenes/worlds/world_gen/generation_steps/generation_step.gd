class_name GenerationStep
extends Node


# Override this function
func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	pass


func execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	_execute_step(data, gen_data, generation_seed)
	pass
