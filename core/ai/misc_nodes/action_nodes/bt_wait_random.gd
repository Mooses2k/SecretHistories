class_name BTWaitRandom extends BTAction


# Choose a random amount of time to wait and wait it


signal character_idled


export var max_time := 2.0
export var min_time := 1.0

var time_left := 0.0
var active := false
var reset := false


func _ready():
	get_tree().connect("physics_frame", self, "idle")


func idle():
	if active:
		active = false
		time_left -= get_physics_process_delta_time()
		reset = false
	elif !reset:
		reset_timer()


func tick(state : CharacterState) -> int:
	if time_left > 0:
		state.move_direction = Vector3.ZERO
		active = true
		return BUSY
	
	reset_timer() # Reset timer in preparation for next execution
	active = false
	return OK


func reset_timer():
	var speech_chance = randf()
	if (speech_chance > 0.95):
		emit_signal("character_idled")
	time_left = rand_range(min_time, max_time)
	reset = true
