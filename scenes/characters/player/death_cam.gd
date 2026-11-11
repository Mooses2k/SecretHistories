extends Node
## Issue #414 death cam. At death the FPS camera mounts to the head bone and
## rides the ragdoll down to the ground, mouse motion nudges a tiny heavily
## damped head look, and a short ray keeps the camera from poking outside the
## walls. The ragdoll itself is the landed PhysicalBoneSimulator3D flow on the
## humanoid base; this node only owns the camera side of the death sequence.
## The GameUI death consumer spawns it on the player's DEAD physical state.

const HEAD_BONE_NAME : String = "DEF-spine.006"
## Radians per mouse pixel: deliberately far below the live aim sensitivity
## so the dead head only creeps.
const LOOK_SCALE : float = 0.0005
## Total head look range in radians, yaw and pitch alike.
const LOOK_MAX : float = 0.3
## Smoothing rate: higher is stiffer; tuned for a heavy, waterlogged feel.
const LOOK_DAMPING : float = 3.0
## Clearance kept between the camera and any wall hit by the clamp ray.
const WALL_MARGIN : float = 0.2

var _active : bool = false
var _camera : Camera3D
var _mount : BoneAttachment3D
# The head look rotation lives on an inner pivot: the BoneAttachment3D
# re-derives its own transform from the bone pose every frame, so it must
# not be the node the look writes to.
var _look_pivot : Node3D
var _target_yaw : float = 0.0
var _target_pitch : float = 0.0
var _yaw : float = 0.0
var _pitch : float = 0.0
var _excluded : Array[RID] = []


## Called by the GameUI death consumer right after this node is added to the
## dead player. Mounts the camera and takes the live controller's hands off
## it by disabling its processing at runtime; the controller script itself is
## not touched.
func setup(player : Node) -> void:
	_camera = player.get_node_or_null("ModelRoot/MainCamera") as Camera3D
	var skeleton : Skeleton3D = player.get_node_or_null(
		"ModelRoot/rig_deform/Skeleton3D") as Skeleton3D
	if _camera == null or skeleton == null:
		push_warning("DeathCam: no camera or skeleton on %s" % player.name)
		return
	var controller : Node = player.get_node_or_null("PlayerController")
	if controller != null:
		controller.process_mode = Node.PROCESS_MODE_DISABLED
	_mount = BoneAttachment3D.new()
	_mount.name = "DeathCamMount"
	_mount.bone_name = HEAD_BONE_NAME
	skeleton.add_child(_mount)
	_look_pivot = Node3D.new()
	_look_pivot.name = "DeathCamLook"
	_mount.add_child(_look_pivot)
	# Keep the global transform so the view does not snap when the mount
	# takes over from ModelRoot.
	_camera.reparent(_look_pivot)
	_collect_exclusions(player)
	_active = true


func _collect_exclusions(player : Node) -> void:
	_excluded.append(player.get_rid())
	var ragdoll : Node = player.get_node_or_null(
		"ModelRoot/rig_deform/Skeleton3D/CharacterRagdoll")
	if ragdoll == null:
		return
	for bone in ragdoll.get_children():
		if bone is PhysicsBody3D:
			_excluded.append((bone as PhysicsBody3D).get_rid())


## Heavy damped head look: GameUI forwards dead-state mouse motion here.
func apply_death_look(relative : Vector2) -> void:
	if not _active:
		return
	_target_yaw = clampf(_target_yaw - relative.x * LOOK_SCALE, -LOOK_MAX, LOOK_MAX)
	_target_pitch = clampf(_target_pitch - relative.y * LOOK_SCALE, -LOOK_MAX, LOOK_MAX)


func _process(delta : float) -> void:
	if not _active:
		return
	var weight : float = 1.0 - exp(-LOOK_DAMPING * delta)
	_yaw = lerpf(_yaw, _target_yaw, weight)
	_pitch = lerpf(_pitch, _target_pitch, weight)
	_look_pivot.rotation = Vector3(_pitch, _yaw, 0.0)


func _physics_process(_delta : float) -> void:
	if not _active:
		return
	_clamp_camera_into_walls()


## Camera-inside-walls guard: a ray from the head mount toward the camera
## pulls the camera back in front of anything between them, so the corpse
## view never clips through the wall or floor it lies against.
func _clamp_camera_into_walls() -> void:
	var space := _camera.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(
		_mount.global_position, _camera.global_position, 1, _excluded)
	var hit : Dictionary = space.intersect_ray(ray)
	if hit.is_empty():
		return
	var to_camera : Vector3 = _camera.global_position - _mount.global_position
	if to_camera.length() < WALL_MARGIN:
		return
	to_camera = to_camera.normalized()
	_camera.global_position = hit["position"] - to_camera * WALL_MARGIN
