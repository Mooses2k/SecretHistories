extends Spatial


onready var character = owner
var facing : Vector3 = Vector3.FORWARD


func _process(delta):
	facing = facing.linear_interpolate(character.character_state.face_direction, 6*delta).normalized()
	look_at(facing + global_transform.origin, Vector3.UP)
#	pass
