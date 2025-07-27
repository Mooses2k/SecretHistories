extends ShapeCast3D
class_name KickCast

@export_flags_3d_physics var kick_mask : int
@export var extra_margin : float = 0.05

var _query_shape : CapsuleShape3D = CapsuleShape3D.new()
var _query_parameters := PhysicsShapeQueryParameters3D.new()

@onready var _debug_mesh : MeshInstance3D = $MeshInstance3D


#TODO: add gridmaps to the _query_parameters exceptions for extra performance
# (since kicking them will never do anything anyway)
func _ready() -> void:
	_query_shape.radius = (shape as SphereShape3D).radius + extra_margin
	_query_parameters.collision_mask = kick_mask
	_query_parameters.shape = _query_shape
	_query_parameters.exclude.push_back((owner as HumanoidCharacter).get_rid())
	_query_parameters.collide_with_areas = true
	_query_parameters.collide_with_bodies = true
	(_debug_mesh.mesh as CapsuleMesh).radius = _query_shape.radius

func get_kick_objects() -> Array[Node3D]:
	var space := PhysicsServer3D.space_get_direct_state(get_world_3d().space)
	force_shapecast_update()
	var displacement : float = (get_closest_collision_unsafe_fraction() * target_position.y)
	var t := global_transform
	t.origin += displacement * 0.5 * t.basis.y
	_query_parameters.transform = t
	_query_shape.height = displacement + 2.0 * _query_shape.radius
	(_debug_mesh.mesh as CapsuleMesh).height = _query_shape.height
	_debug_mesh.global_transform = t
	var query_result := space.intersect_shape(_query_parameters)
	
	var result : Dictionary
	for i : int in query_result.size():
		var collider = query_result[i].collider
		if collider is Node3D:
			result[collider] = null
	#space.intersect_shape()
	return Array(result.keys(), TYPE_OBJECT, &"Node3D", null)
