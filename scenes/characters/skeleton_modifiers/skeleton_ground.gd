@tool
extends SkeletonModifier3D
class_name GroundedSkeletonModifier
## This script looks through a list of bones to detect if any of them is
## below the floor (lower than the origin of the skeleton itself), and moves
## the whole skeleton up by the corresponding amount if it is, keeping the
## skeleton grounded

@export var offset : float = 0.0

const FEET_BONES : Array[String] = ["DEF-foot.R", "DEF-foot.L", "DEF-toe.R", "DEF-toe.L"]
var bone_ids : Array[int] = []

func _ready() -> void:
	for bone_name : String in FEET_BONES:
		var bone_id : int = get_skeleton().find_bone(bone_name)
		bone_ids.push_back(bone_id)

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if not is_instance_valid(skeleton): return
	var lowest_height : float = 0.0
	for bone_id : int in bone_ids:
		var bone_position : Vector3 = skeleton.get_bone_global_pose(bone_id).origin
		lowest_height = minf(bone_position.y, lowest_height)
	var root_bone_pose := skeleton.get_bone_global_pose(0)
	root_bone_pose.origin.y += -lowest_height + offset
	skeleton.set_bone_global_pose(0, root_bone_pose)
	#position.y = -lowest_height + offset
