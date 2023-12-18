class_name CharacterState
extends Reference


var interest_machine
var character
var target


var move_direction     := Vector3.ZERO    setget set_move_direction
var face_direction     := Vector3.FORWARD setget set_face_direction
var target_position    := Vector3.ZERO    setget set_target_position
var interaction_target :  Node = null


var path := [] setget , get_path
var path_needs_update := false


func _init(_character):
	character = _character


func set_face_direction(value : Vector3) -> void:
	value.y = 0.0
	if not value.is_equal_approx(Vector3.ZERO):
		face_direction = value.normalized()


func set_move_direction(value : Vector3) -> void:
	value.y = 0.0
	move_direction = value.normalized() * min(value.length(), 1.0)


func get_path() -> Array:
	if path_needs_update:
		var map = character.get_world().navigation_map
		var nav = NavigationServer
		path = nav.map_get_path(map, character.global_transform.origin, target_position, false)
		path_needs_update = false
	return path


func set_target_position(value : Vector3) -> void:
	var map = character.get_world().navigation_map
	var nav = NavigationServer
	value = nav.map_get_closest_point(map, value)
	if !value.distance_squared_to(target_position) < 0.25:
		target_position = value
		path_needs_update = true


# May or may not be necessary to make sure cultists aren't floppy after death
func die() -> void:
	move_direction = Vector3.ZERO
	path = Array()
