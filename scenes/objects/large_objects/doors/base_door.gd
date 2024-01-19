extends Node3D


var hinge_joint : RID

@onready var door_body = %DoorBody
@onready var doorway_gaps_filler = %DoorwayGapsFiller
@onready var door_hinge = $DoorHingeZAxis


func _ready():
	door_body.add_collision_exception_with(doorway_gaps_filler)
	hinge_joint = PhysicsServer3D.joint_create()
	PhysicsServer3D.joint_make_hinge(hinge_joint, door_body.get_rid(), door_body.global_transform.inverse()*door_hinge.global_transform, doorway_gaps_filler.get_rid(), doorway_gaps_filler.global_transform.inverse()*door_hinge.global_transform)
	PhysicsServer3D.hinge_joint_set_flag(hinge_joint, PhysicsServer3D.HINGE_JOINT_FLAG_USE_LIMIT, true)
	PhysicsServer3D.hinge_joint_set_param(hinge_joint, PhysicsServer3D.HINGE_JOINT_LIMIT_LOWER, deg_to_rad(-1.0))
	PhysicsServer3D.hinge_joint_set_param(hinge_joint, PhysicsServer3D.HINGE_JOINT_LIMIT_UPPER, deg_to_rad(120.0))
