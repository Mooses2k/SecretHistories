class_name BT_Target_Defend
extends BT_Node

### Returns to a specific place when lose track of player


export var minimum_radius : float = 0.0
export var maximum_radius : float = 2.0

var defended_location : Vector3 = Vector3.ZERO


func tick(state : CharacterState) -> int:
	var character = state.character
	
	# If we haven't set the defended location yet, it's where we are spawned
	if defended_location == Vector3.ZERO:
		defended_location = character.global_transform.origin
	
	var radius = rand_range(minimum_radius, maximum_radius)
	var angle = rand_range(0, 2 * PI)
	var offset = (Vector3.FORWARD * radius).rotated(Vector3.UP, angle)
	state.target_position = state.character.global_transform.origin + offset
	return Status.SUCCESS
