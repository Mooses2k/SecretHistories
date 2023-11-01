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

const PLAYER_FACING_ROTATIONS = {
	WorldData.Direction.NORTH: 0,
	WorldData.Direction.EAST: 1.5*PI,
	WorldData.Direction.SOUTH: PI,
	WorldData.Direction.WEST: 0.5*PI,
}

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready() -> void:
	var game_world := get_parent() as GameWorld
	if game_world and is_instance_valid(_spawn_position):
		game_world.world_data.player_spawn_positions[RoomData.OriginalPurpose.UP_STAIRCASE] = \
				{
					"position": _spawn_position.global_translation,
					"y_rotation": PLAYER_FACING_ROTATIONS[facing_direction],
				}
	
	match GameManager.game.current_floor_level:
		-1:
			$LevelMessage.text = "ONLY WAY FORWARD IS DOWN"
		-2:
			$LevelMessage.text = "IT CALLS FROM THE DEPTHS"
		-3:
			$LevelMessage.text = "COMET WHISPERS IN MY HEAD"
		-4:
			var chance = randf()
			if chance <= .999:
				$LevelMessage.text = "I CAN HEAR IT SINGING"
			else:
				$LevelMessage.text = "IT BELONGS IN A MUSEUM" + "\n" + "\n" + ":)" + "\n" + "\n" + "JUST KIDDING, GONNA PAWN IT"
		-5:
			$LevelMessage.text = "IT IS WITH US NOW"
		
	$LevelMessage/Timer.start()

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
	
	Events.emit_signal("up_staircase_used")


func _on_Timer_timeout():
	$LevelMessage.visible = false

### -----------------------------------------------------------------------------------------------
