# Write your doc string for this file here
extends LevelStaircase

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const DOWN_FACING_ROTATIONS = {
	WorldData.Direction.NORTH: 1.5 * PI,
	WorldData.Direction.EAST: PI,
	WorldData.Direction.SOUTH: 0.5 * PI,
	WorldData.Direction.WEST: 0,
}

const PLAYER_FACING_ROTATIONS = {
	WorldData.Direction.NORTH: 0,
	WorldData.Direction.EAST: 1.5 * PI,
	WorldData.Direction.SOUTH: PI,
	WorldData.Direction.WEST: 0.5 * PI,
}

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready() -> void:
	var game_world := get_parent() as GameWorld
	if game_world and is_instance_valid(_spawn_position):
		game_world.world_data.player_spawn_positions[RoomData.OriginalPurpose.DOWN_STAIRCASE] = \
				{
					"position": _spawn_position.global_translation,
					"y_rotation": PLAYER_FACING_ROTATIONS[facing_direction],
				}

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _get_facing_rotation() -> float:
	return DOWN_FACING_ROTATIONS[facing_direction]

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

func _on_DownDetector_body_entered(body: Node) -> void:
	var player = body as Player
	if player == null:
		return
	
	Events.emit_signal("down_staircase_used")

### -----------------------------------------------------------------------------------------------
