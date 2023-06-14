class_name CharacterState
extends Reference


var character

var move_direction : Vector3 = Vector3.ZERO setget set_move_direction
var face_direction : Vector3 = Vector3.FORWARD setget set_face_direction
var target_position : Vector3 = Vector3.ZERO setget set_target_position
var path : Array = Array() setget ,get_path
var interaction_target : Node = null

var path_needs_update : bool = false


func _init(_character):
	character = _character
#	target_position = character.global_transform.origin


func set_face_direction(value : Vector3):
	value.y = 0.0
	if not value.is_equal_approx(Vector3.ZERO):
		face_direction = value.normalized()


func set_move_direction(value : Vector3):
	value.y = 0.0
	move_direction = value.normalized() * min(value.length(), 1.0)


func get_path():
	if path_needs_update:
		var map = character.get_world().navigation_map
		var nav = NavigationServer
		path = nav.map_get_path(map, character.global_transform.origin, target_position, false)
		path_needs_update = false
	return path


func set_target_position(value : Vector3):
	var map = character.get_world().navigation_map
	var nav = NavigationServer
	value = nav.map_get_closest_point(map, value)
	if not value.distance_squared_to(target_position) < 0.25:
		target_position = value
		path_needs_update = true
