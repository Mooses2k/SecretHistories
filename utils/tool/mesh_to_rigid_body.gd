@tool
extends EditorScript


func _run() -> void:
	var selected_nodes : Array = get_editor_interface().get_selection().get_selected_nodes()
	for _node in selected_nodes:
		var node : MeshInstance3D = _node as MeshInstance3D
		if (!is_instance_valid(node)):
			continue
		var owner : Node = node.owner
		var parent : Node = node.get_parent()
		var rigid_body : RigidBody3D = RigidBody3D.new()
		var collision_shape : CollisionShape3D = CollisionShape3D.new()
		var box_shape : BoxShape3D = BoxShape3D.new()
		var aabb : AABB = node.get_aabb()
		box_shape.extents = aabb.size*0.5
		collision_shape.shape = box_shape
		var offset: Vector3 = aabb.get_center()
		node.replace_by(rigid_body)
		rigid_body.transform = node.transform
		rigid_body.transform.origin = node.transform * (offset)
		node.transform = Transform3D.IDENTITY
		node.transform.origin = -offset
		rigid_body.add_child(node)
		rigid_body.add_child(collision_shape)
		rigid_body.owner = owner
		collision_shape.owner = owner
		node.owner = owner
