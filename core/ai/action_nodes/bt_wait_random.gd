class_name BT_Wait_Random
extends BT_Node


signal character_idled

export var max_time : float = 2.0
export var min_time : float = 1.0

var time_left : float = 0.0
var active : bool = false
var reset : bool = false


func _ready():
	get_tree().connect("physics_frame", self, "idle")


func idle():
	if active:
		active = false
		time_left -= get_physics_process_delta_time()
		reset = false
	elif not reset:
		reset_timer()


func tick(state : CharacterState) -> int:
	if time_left > 0:
		state.move_direction = Vector3.ZERO
		active = true
		return Status.RUNNING
	else:
		active = false
		return Status.SUCCESS


func reset_timer():
	var speech_chance = randf()
	if (speech_chance > 0.95):
		emit_signal("character_idled")
		print("Idle speech signalled")
	time_left = rand_range(min_time, max_time)
	reset = true
