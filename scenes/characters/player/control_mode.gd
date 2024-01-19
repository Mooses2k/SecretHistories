class_name ControlMode
extends Node


@export var _cam_path : NodePath
var is_active : bool = false: set = set_active
@onready var _camera : ShakeCamera = get_node(_cam_path) as ShakeCamera


func _ready():
	set_active(false)


func set_active(value : bool):
	is_active = value
	_camera.current = value
	set_process_unhandled_input(value)
	set_process_input(value)


func update(delta):   # added delta when programming recoil
	pass


func get_movement_basis() -> Basis:
	return Basis.IDENTITY


func get_interaction_target() -> Node:
	return null


func get_grab_target() -> RigidBody3D:
	return null


func get_grab_global_position() -> Vector3:
	return Vector3.ZERO


func get_grab_target_position(distance : float) -> Vector3:
	return Vector3.ZERO


func get_target_placement_position() -> Vector3:
	return Vector3.ZERO


func get_aim_direction() -> Vector3:
	return Vector3.FORWARD
