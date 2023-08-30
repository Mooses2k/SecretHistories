tool
extends SkeletonIK


export var IK_enabled : bool = false setget set_ik_enabled


func set_ik_enabled(value : bool):
	if Engine.editor_hint:
		IK_enabled = value
		if IK_enabled:
			start()
		else:
			stop()


func _ready():
	start()
