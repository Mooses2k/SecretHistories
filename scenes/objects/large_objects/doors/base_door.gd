extends Spatial


var hinge_joint : RID

onready var door_body = $"%DoorBody"
onready var doorway_gaps_filler = $"%DoorwayGapsFiller"
onready var door_hinge = $DoorHingeZAxis


func _ready():
	door_body.add_collision_exception_with(doorway_gaps_filler)
	hinge_joint = PhysicsServer.joint_create_hinge(door_body.get_rid(), door_body.global_transform.inverse()*door_hinge.global_transform, doorway_gaps_filler.get_rid(), doorway_gaps_filler.global_transform.inverse()*door_hinge.global_transform)
	PhysicsServer.hinge_joint_set_flag(hinge_joint, PhysicsServer.HINGE_JOINT_FLAG_USE_LIMIT, true)
	PhysicsServer.hinge_joint_set_param(hinge_joint, PhysicsServer.HINGE_JOINT_LIMIT_LOWER, deg2rad(-1.0))
	PhysicsServer.hinge_joint_set_param(hinge_joint, PhysicsServer.HINGE_JOINT_LIMIT_UPPER, deg2rad(120.0))
