extends Area


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
export var force_curve : Curve
export var max_distance : float = 0.6
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	for body in get_overlapping_bodies():
		if body.is_in_group(Groups.CHARACTER):
			var character = body
			var direction : Vector3 = global_transform.origin - character.global_transform.origin
			direction.y = 0.0
			var distance = direction.length()
			direction = direction.normalized()
			var force = direction*force_curve.interpolate(distance/max_distance)
			character.apply_central_impulse(force*delta)
#	for
##	pass
