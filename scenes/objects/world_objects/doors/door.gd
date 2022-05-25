extends Spatial
class_name Door

enum HingeSide {
	LEFT,
	RIGHT
}

export(HingeSide) var hinge_side : int = HingeSide.RIGHT setget set_hinge_side
export var max_angle = 90.0 setget set_max_angle
export var min_angle = 0.0 setget set_min_angle

var navmesh : NavigationMeshInstance = null
export var door_lock_count : int = 0 setget set_door_lock_count
var door_locked_transform : Transform

onready var door_body : RigidBody = $DoorBody

func set_door_lock_count(value : int):
	if value == door_lock_count:
		return
	door_lock_count = value
	if not is_inside_tree():
		yield(self, "tree_entered")
	if door_lock_count == 0: #unlock door
		$DoorBody.mode = RigidBody.MODE_RIGID
		if navmesh:
			navmesh.enabled = true
	else: #lock door
		if navmesh:
			navmesh.enabled = false
		$DoorBody.transform = door_locked_transform
		$DoorBody.mode = RigidBody.MODE_STATIC
		
func _enter_tree():
	door_locked_transform = $DoorBody.transform

func set_hinge_side(value : int):
	if value == hinge_side:
		return
	hinge_side = value
	if not is_inside_tree():
		yield(self, "tree_entered")
	var hinge_sign = -1 if hinge_side == HingeSide.RIGHT else 1.0
	if sign($Hinge.translation.x) != hinge_sign:
		$Hinge.translation.x *= -1
	if sign($DoorBody/BottomHinge.translation.x) != hinge_sign:
		$DoorBody/BottomHinge.translation.x *= -1
	if sign($DoorBody/TopHinge.translation.x) != hinge_sign:
		$DoorBody/TopHinge.translation.x *= -1
	if sign($DoorBody/LockLoop.translation.x) != -hinge_sign:
		$DoorBody/LockLoop.translation.x *= -1
	if sign($DoorFrame/LockLoop.translation.x) != -hinge_sign:
		$DoorFrame/LockLoop.translation.x *= -1
	set_max_angle(max_angle)
	set_min_angle(min_angle)
		
func set_max_angle(value : float):
	max_angle = value
	if not is_inside_tree():
		yield(self, "tree_entered")
	if hinge_side == HingeSide.RIGHT:
		$DoorBody.max_angle = max_angle
	else:
		$DoorBody.min_angle = -max_angle

func set_min_angle(value : float):
	min_angle = value
	if not is_inside_tree():
		yield(self, "tree_entered")
	if hinge_side == HingeSide.RIGHT:
		$DoorBody.min_angle = min_angle
	else:
		$DoorBody.max_angle = -min_angle
