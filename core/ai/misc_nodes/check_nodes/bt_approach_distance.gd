class_name BTApproachRandomDistance extends BTCheck


# Choose and check if have reached an approach distance.
# For instance, choose a target and succeed when within a randomly chosen
# 4-8m of the target.


export var threshold_factor := 1.5
export var min_distance := 4.0
export var max_distance := 8.0


var ticks_since_active := 0
var target_distance := 0.0
var target_reached := false
var distance : float = INF

func _pre_tick() -> void:
	ticks_since_active += 1
	if ticks_since_active > 1:
		target_distance = rand_range(min_distance, max_distance)
		target_reached = false

func _tick(state : CharacterState) -> int:
	var _speech_chance = randf()
	ticks_since_active = 0
	distance = state.character.global_transform.origin.distance_to(state.target_position)
	
	if target_reached:
		# Since target distance changes every frame, this prevents the character from
		# constantly repositioning every time it changes
		if distance > target_distance * threshold_factor:
			target_reached = false
			return BTResult.FAILED
		state.move_direction = Vector3.ZERO
		return BTResult.OK
	
	if distance < target_distance:
		target_reached = true
		state.move_direction = Vector3.ZERO
		return BTResult.OK
	return BTResult.FAILED

func _get_node_state() -> Dictionary:
	return {distance = distance, target_distance = target_distance}
