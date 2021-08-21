tool
extends Area

var _mesh : CylinderMesh = CylinderMesh.new()
onready var _mesh_instance : MeshInstance = $MeshInstance as MeshInstance
onready var _collision_shape : CollisionShape = $CollisionShape as CollisionShape
	
func update_mesh(FOV : float, distance : float):
	if not is_inside_tree():
		return
	_mesh.rings = 0
	_mesh.radial_segments = 4
	_mesh.height = distance
	_mesh.top_radius = 0.0
	_mesh.bottom_radius = distance*tan(deg2rad(FOV/2))/(sqrt(2)*0.5)
	_mesh_instance.transform.origin.z = -distance*0.5
	_collision_shape.shape = _mesh.create_convex_shape()
	_collision_shape.transform.origin.z = -distance*0.5
	pass

func _ready():
	_mesh_instance.mesh = _mesh
	pass # Replace with function body.
