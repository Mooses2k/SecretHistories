@tool
extends Node3D

@onready var skeleton_3d: Skeleton3D = $rig_deform/Skeleton3D



@export var glb_root : Node3D = null:
	set(value):
		if not check_value(value):
			glb_root = null
			return
		glb_root = value
		set_model_skeleton.call_deferred()

func check_value(value : Node3D) -> bool:
	if not is_instance_valid(value):
		return false
	if value.scene_file_path.is_empty():
		push_warning("glb_root does not point to an instantiated scene")
		return false
	if value.get_child_count() == 0:
		push_warning("glb_root does not have any children")
		return false
	if value.get_child(0).owner != value:
		push_warning("glb_root does not point to an instantiated scene")
		return false
	return true

func set_model_skeleton():
	var skeleton = find_skeleton(glb_root)
	if not is_instance_valid(skeleton): return
	var queue = skeleton.get_children()
	for node in queue:
		if node is MeshInstance3D:
			if node.skeleton == ^"..":
				node.skeleton = node.get_path_to(skeleton_3d)

func find_skeleton(from : Node) -> Skeleton3D:
	var queue = from.get_children()
	while not queue.is_empty():
		var n = queue.pop_back()
		if n is Skeleton3D:
			return n
		queue.append_array(n.get_children())
	return null
