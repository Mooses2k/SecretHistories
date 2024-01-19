@tool
extends SkeletonIK3D


@export var IK_enabled : bool = false: set = set_ik_enabled


func set_ik_enabled(value : bool):
	if Engine.is_editor_hint():
		IK_enabled = value
		if IK_enabled:
			start()
		else:
			stop()


func _ready():
	start()
