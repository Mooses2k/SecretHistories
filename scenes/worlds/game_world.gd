class_name GameWorld
extends Node

const CELL_SIZE : float = 2.0

signal world_data_changed(new_data, new_size)

var navigation : Navigation
var world_data : Array setget set_world_data
var world_size : int = 0

# Override this function
func get_player_spawn_position() -> Vector3:
	return Vector3.ZERO


func set_world_data(value : Array):
	world_data = value
	world_size = value.size()
	emit_signal("world_data_changed", world_data, world_size)


func world_to_grid(position : Vector3) -> Vector3:
	var result : Vector3 = (position/CELL_SIZE).floor()
	result.y = 0
	return result


func grid_to_world(position : Vector3) -> Vector3:
	var result : Vector3 = (position + Vector3.ONE*0.5)*CELL_SIZE
	result.y = 0
	return result
