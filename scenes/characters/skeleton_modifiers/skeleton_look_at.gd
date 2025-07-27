@tool
extends SkeletonModifier3D
class_name LookAtSkeletonModifier
## This script looks through a list of bones to detect if any of them is
## below the floor (lower than the origin of the skeleton itself), and moves
## the whole skeleton up by the corresponding amount if it is, keeping the
## skeleton grounded

@export var target_node : Node3D

const BASE_BONE = "DEF-spine.004"
const HEAD_BONE = "DEF-spine.006"

# Array of bones, 0 is HEAD
var bone_ids : Array[int] = []

var max_angle := deg_to_rad(60)


func _ready() -> void:
	var skeleton := get_skeleton()
	var current_bone := skeleton.find_bone(HEAD_BONE)
	var base_bone_id := skeleton.find_bone(BASE_BONE)
	bone_ids.push_back(current_bone)
	while current_bone != base_bone_id:
		current_bone = skeleton.get_bone_parent(current_bone)
		assert(current_bone != -1)
		bone_ids.push_back(current_bone)
	bone_ids.reverse()

func _process_modification() -> void:
	if not is_inside_tree(): return
	if not is_instance_valid(target_node): return
	var skeleton := get_skeleton()
	if not is_instance_valid(skeleton): return
	var base_pose : Transform3D = skeleton.get_bone_rest(bone_ids[-1])
	var parent_pose_global : Transform3D = skeleton.get_bone_global_pose(bone_ids[-2])
	var target_position : Vector3 = skeleton.to_local(target_node.global_position)
	base_pose = parent_pose_global*base_pose
	var look_rotation : Quaternion = Quaternion(base_pose.basis.z, base_pose.origin.direction_to(target_position)).normalized()
	var angle : float = abs(look_rotation.get_angle())
	if angle > max_angle:
		look_rotation = Quaternion.IDENTITY.slerp(look_rotation, max_angle/angle)
	base_pose.basis = Basis(look_rotation)*base_pose.basis
	skeleton.set_bone_global_pose(bone_ids[-1], base_pose)

	#for b in bone_ids.size():
		#var current_head_pose := skeleton.get_bone_global_pose(bone_ids[-1])
		#var target_basis := current_head_pose.looking_at(target_position, Vector3.UP, true).basis
		#var current_pose = skeleton.get_bone_global_pose(bone_ids[b])
#
		#target_basis = target_basis * current_head_pose.basis.inverse()
#
		#var step_rotation = Basis.IDENTITY.slerp(target_basis.get_rotation_quaternion(), 1.0/bone_ids.size())
#
		#current_pose.basis = step_rotation*current_pose.basis
#
		#skeleton.set_bone_global_pose(bone_ids[b], current_pose)
		#skeleton.force_update_bone_child_transform(bone_ids[b])
	#position.y = -lowest_height + offset
