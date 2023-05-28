class_name GameWorld
extends Spatial


signal generation_finished()

var world_data : WorldData
onready var world_generator : GenerationManager = $GenerationManager
onready var gridmaps = $Gridmaps
onready var navigation = $Navigation


func _ready() -> void:
	world_data = world_generator.generate()
	gridmaps.data = world_data
	gridmaps.update_gridmaps()
	navigation.data = world_data
	navigation.update_navigation()
	world_data.print_world_map()
	emit_signal("generation_finished")


# Override this function
func get_player_spawn_position() -> Vector3:
	return Vector3.ZERO


func world_to_grid(position : Vector3) -> Vector3:
	var result : Vector3 = (position/WorldData.CELL_SIZE).floor()
	result.y = 0
	return result


func grid_to_world(position : Vector3) -> Vector3:
	var result : Vector3 = (position + Vector3.ONE*0.5)*WorldData.CELL_SIZE
	result.y = 0
	return result
