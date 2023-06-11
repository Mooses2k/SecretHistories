tool
class_name BoxOutlineMesh
extends ArrayMesh


export var size : Vector3 = Vector3.ONE setget set_size


func set_size(value : Vector3):
	size = value
	regenerate()


func _init():
	regenerate()
	pass


func regenerate():
	clear_surfaces()
	var e = size * 0.5;
	var vertices = PoolVector3Array([
		Vector3(-e.x, -e.y, -e.z), # 0 ---
		Vector3(-e.x, -e.y, +e.z), # 1 --+
		Vector3(-e.x, +e.y, -e.z), # 2 -+-
		Vector3(-e.x, +e.y, +e.z), # 3 -++
		Vector3(+e.x, -e.y, -e.z), # 4 +--
		Vector3(+e.x, -e.y, +e.z), # 5 +-+
		Vector3(+e.x, +e.y, -e.z), # 6 ++-
		Vector3(+e.x, +e.y, +e.z), # 7 +++
	])
	var indices = PoolIntArray([
		0, 1,
		0, 2,
		0, 4,
		1, 3,
		1, 5,
		2, 3,
		2, 6,
		3, 7,
		4, 5,
		4, 6,
		5, 7,
		6, 7
	])
	var arrays = Array()
	arrays.resize(ARRAY_MAX)
	arrays[ARRAY_VERTEX] = vertices
	arrays[ARRAY_INDEX] = indices
	add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
