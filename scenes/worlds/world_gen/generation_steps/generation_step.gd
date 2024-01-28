class_name GenerationStep
extends Node


const ROOM_ARRAY_KEY = "rooms"
const LAST_FLOOR_KEY = "is_last_floor"


# Override this function
func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	pass


func execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	_execute_step(data, gen_data, generation_seed)
	pass
