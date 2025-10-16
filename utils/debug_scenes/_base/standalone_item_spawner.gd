## Standalone Item Spawner for Debug Scenes
## Spawns world data objects without requiring full game setup
extends Spawner

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

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

func _on_game_world_generation_finished():
	var data := owner.world_data as WorldData
	
	# Spawn all world data objects using unified SpawnData interface
	var objects_to_spawn := data.get_objects_to_spawn()
	for cell_index in objects_to_spawn:
		var spawn_data := objects_to_spawn[cell_index] as SpawnData
		spawn_data.spawn_item_in(owner, true)  # Enable logging
	
	await get_tree().idle_frame
	
	has_finished_spawning = true
	emit_signal("spawning_finished")

### -----------------------------------------------------------------------------------------------
