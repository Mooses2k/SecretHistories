# Write your doc string for this file here
extends LevelStaircase

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const UP_FACING_ROTATIONS = {
	WorldData.Direction.NORTH: PI,
	WorldData.Direction.EAST: 0.5*PI,
	WorldData.Direction.SOUTH: 0,
	WorldData.Direction.WEST: 1.5*PI,
}

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready() -> void:
	var game_world := get_parent() as GameWorld
	if game_world and is_instance_valid(_spawn_position):
		game_world.world_data.player_spawn_positions[RoomData.OriginalPurpose.UP_STAIRCASE] = \
				_spawn_position.global_translation

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _get_facing_rotation() -> float:
	return UP_FACING_ROTATIONS[facing_direction]

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

func _on_UpDetector_body_entered(body: Node) -> void:
	var player = body as Player
	if player == null:
		return
	
	print("Player is going Upstairs")

### -----------------------------------------------------------------------------------------------
