class_name BTSelectRandomTarget extends BTAction


# Select a random nearby tile and set it as the target position


export var minimum_radius := 1.0
export var maximum_radius := 6.0


func tick(state : CharacterState) -> int:
	var radius := rand_range(minimum_radius, maximum_radius)
	var angle := rand_range(0, 2*PI)
	var offset := (Vector3.FORWARD * radius).rotated(Vector3.UP, angle)
	state.target_position = state.character.global_transform.origin + offset
	return BTResult.OK
