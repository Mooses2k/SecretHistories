class_name GameWorld
extends Node3D


signal generation_finished()
signal spawning_world_scenes_finished

var world_data : WorldData
@onready var world_generator : GenerationManager = $GenerationManager
@onready var gridmaps = $Gridmaps
@onready var navigation = $Navigation

@onready var _spawners := [$CharacterSpawner]


func _ready() -> void:
	_connect_signals()


func create_world(is_last_floor: bool, p_floor_size: int = -1) -> void:
	if p_floor_size != -1:
		world_generator.world_size_x = p_floor_size
		world_generator.world_size_z = p_floor_size
	world_data = world_generator.generate(is_last_floor)
	gridmaps.data = world_data
	gridmaps.update_gridmaps()
	navigation.data = world_data
	navigation.update_navigation()
	world_data.print_world_map()
	emit_signal("generation_finished")


# Override this function
func set_player_on_spawn_position(player: Player, _is_going_downstairs: bool) -> void:
	print("spawning player at position")
	var spawn_data = {
		"position": Vector3.ZERO,
		"y_rotation": 0.0,
	}

	player.position = spawn_data.position
	player.rotation.y = spawn_data.y_rotation


func world_to_grid(position : Vector3) -> Vector3:
	var result : Vector3 = (position / WorldData.CELL_SIZE).floor()
	result.y = 0
	return result


func grid_to_world(position : Vector3) -> Vector3:
	var result : Vector3 = (position + Vector3.ONE * 0.5) * WorldData.CELL_SIZE
	result.y = 0
	return result


func _connect_signals() -> void:
	# Connect generation_finished to unified spawning system
	if not is_connected("generation_finished", Callable(self, "_on_generation_finished")):
		connect("generation_finished", Callable(self, "_on_generation_finished"))
	
	# Connect remaining spawners (CharacterSpawner for continuous spawning)
	for node in _spawners:
		var spawner := node as Spawner
		if not is_connected("generation_finished", Callable(spawner, "_on_game_world_generation_finished")):
			connect("generation_finished", Callable(spawner, "_on_game_world_generation_finished"))

		if not spawner.is_connected("spawning_finished", Callable(self, "_on_spawner_spawning_finished")):
			spawner.connect("spawning_finished", Callable(self, "_on_spawner_spawning_finished"))


func _on_generation_finished() -> void:
	# Spawn all world data objects using unified spawn_data system
	_spawn_world_data_objects()
	
	# Check if all spawners have finished
	_check_spawning_completion()


func _spawn_world_data_objects() -> void:
	var objects_to_spawn := world_data.get_objects_to_spawn()
	var characters_to_spawn := world_data.get_characters_to_spawn()
	
	# Spawn regular objects using unified SpawnData interface
	for cell_index in objects_to_spawn:
		var spawn_data := objects_to_spawn[cell_index] as SpawnData
		spawn_data.spawn_item_in(self, true)  # Enable logging
	
	# Spawn characters using unified SpawnData interface
	for cell_index in characters_to_spawn:
		var spawn_data := characters_to_spawn[cell_index] as CharacterSpawnData
		spawn_data.spawn_character_in(self, true)  # Enable logging


func _on_spawner_spawning_finished() -> void:
	_check_spawning_completion()


func _check_spawning_completion() -> void:
	var has_all_finished := true

	for node in _spawners:
		var spawner := node as Spawner
		if not spawner.has_finished_spawning:
			has_all_finished = false
			break

	if has_all_finished:
		emit_signal("spawning_world_scenes_finished")
