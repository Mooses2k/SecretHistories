class_name GameWorld
extends Spatial


signal generation_finished()
signal spawning_world_scenes_finished

var world_data : WorldData
onready var world_generator : GenerationManager = $GenerationManager
onready var gridmaps = $Gridmaps
onready var navigation = $Navigation

onready var _spawners := [$ItemSpawner, $CharacterSpawner]


func _ready() -> void:
	_connect_signals()


func create_world() -> void:
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


func _connect_signals() -> void:
	for node in _spawners:
		var spawner := node as Spawner
		if not is_connected("generation_finished", spawner, "_on_game_world_generation_finished"):
			connect("generation_finished", spawner, "_on_game_world_generation_finished")
		
		if not spawner.is_connected("spawning_finished", self, "_on_spawner_spawning_finished"):
			spawner.connect("spawning_finished", self, "_on_spawner_spawning_finished")


func _on_spawner_spawning_finished() -> void:
	var has_all_finished := true
	
	for node in _spawners:
		var spawner := node as Spawner
		if not spawner.has_finished_spawning:
			has_all_finished = false
			break
	
	if has_all_finished:
		emit_signal("spawning_world_scenes_finished")
