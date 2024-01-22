extends Node

export var frame_interval : int = 1

var frame_count : int = 0
var kick_raycast : RayCast


func _ready():
	yield(owner, "ready")
	kick_raycast = owner.legcast
	pass # Replace with function body.



func _physics_process(delta):
	var collider = kick_raycast.get_collider() as Node
	if is_instance_valid(collider) and collider is DoorInteractable:
		frame_count += 1
	else:
		frame_count = 0
	if frame_count >= frame_interval:
		owner.kick()
