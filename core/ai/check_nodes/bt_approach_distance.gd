class_name BT_Approach_Random_Distance
extends BT_Node


export var min_distance : float = 4.0
export var max_distance : float = 8.0
export var threshold_factor : float = 1.5

var target_distance : float = 0.0
var target_reached : bool = false
var ticks_since_active : int = 0

export var listener : NodePath
onready var _listener : SoundListener = get_node(listener) as SoundListener


func idle():
	ticks_since_active += 1
	if ticks_since_active > 1:
		target_distance = rand_range(min_distance, max_distance)
		target_reached = false


func tick(state : CharacterState) -> int:
	var speech_chance = randf()
	ticks_since_active = 0
	var distance : float = state.character.global_transform.origin.distance_to(state.target_position)
	if target_reached:
		if distance > target_distance * threshold_factor:
			target_reached = false
			return Status.FAILURE
		_listener.sound_detected = false
		return Status.SUCCESS
	else:
		if distance < target_distance:
			target_reached = true
			_listener.sound_detected = false
			return Status.SUCCESS
		return Status.FAILURE


func _ready():
	get_tree().connect("physics_frame", self, "idle")
