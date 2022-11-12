class_name CharacterState
extends Reference


var move_direction : Vector3 = Vector3.ZERO setget set_move_direction
var face_direction : Vector3 = Vector3.FORWARD setget set_face_direction
var target_position : Vector3 = Vector3.ZERO setget set_target_position
var path : Array = Array()
var interaction_target : Node = null

var character


func _init(_character):
	character = _character
#	target_position = character.global_transform.origin


func set_face_direction(value : Vector3):
	value.y = 0.0
	if not value.is_equal_approx(Vector3.ZERO):
		face_direction = value.normalized()


func set_move_direction(value : Vector3):
	value.y = 0.0
	move_direction = value.normalized()*min(value.length(), 1.0)


func set_target_position(value : Vector3):
	var nav = GameManager.game.level.navigation as Navigation
	value = nav.get_closest_point(value)
	if not value.is_equal_approx(target_position):
		target_position = value
		path = nav.get_simple_path(character.global_transform.origin, target_position)
