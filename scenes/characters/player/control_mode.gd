extends Node
class_name ControlMode

export var _camera : NodePath
var is_active : bool = false setget set_active
onready var camera : Camera = get_node(_camera) as Camera

func _ready():
	set_active(false)

func set_active(value : bool):
	is_active = value
	camera.current = value
	set_process_unhandled_input(value)
	set_process_input(value)

func update():
	pass

func get_movement_basis() -> Basis:
	return Basis.IDENTITY

func get_interaction_target() -> Node:
	return null
