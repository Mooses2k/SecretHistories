class_name BTGoToTargetWithAgent extends BTAction


# Move to currently selected target position


export var threshold : float = 0.5 setget set_threshold
var _thresold_squared : float = 0.25

onready var agent : NavigationAgent = owner.get_node("%NavigationAgent") as NavigationAgent
var queued_velocity : Vector3 = Vector3.ZERO
var velocity_computed : bool = false

func set_threshold(value : float):
	threshold = value
	_thresold_squared = value*value


func on_agent_velocity_computed(velocity : Vector3):
	queued_velocity = velocity
	velocity_computed = true

func _tick(state : CharacterState) -> int:
	var character = state.character as Character
	if agent.get_target_location() != state.target_position:
		agent.set_target_location(state.target_position)
		queued_velocity = Vector3.ZERO
		velocity_computed = true
	
	if agent.is_target_reached():
		return BTResult.OK
	
	if agent.is_navigation_finished():
		return BTResult.FAILED
	
	if velocity_computed:
		velocity_computed = false
		state.move_direction = queued_velocity.normalized()
		if not state.move_direction.is_equal_approx(Vector3.ZERO):
			state.face_direction = state.move_direction
		var next_position = agent.get_next_location()
		var velocity = (next_position - character.global_translation).normalized()*character.move_speed
		agent.connect("velocity_computed", self, "on_agent_velocity_computed", [], CONNECT_ONESHOT)
		agent.set_velocity(velocity)
		
	
	return BTResult.RUNNING

