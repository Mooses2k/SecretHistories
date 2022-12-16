tool
extends ArrayMesh
class_name MeshTransform


export var mesh : Mesh
export var transform : Transform
export var regenerate : bool = false setget set_regenerate


func set_regenerate(value : bool):
	if value and Engine.editor_hint:
		mesh_transform()
		pass


func mesh_transform():
	var surface_count = self.get_surface_count()
	for i in surface_count:
		self.surface_remove(surface_count - i - 1)
	if mesh == null:
		printerr("No mesh to update")
	for surface_index in mesh.get_surface_count():
		var arrays = mesh.surface_get_arrays(surface_index)
		for i in arrays[Mesh.ARRAY_VERTEX].size():
			arrays[Mesh.ARRAY_VERTEX][i] = transform.xform(arrays[Mesh.ARRAY_VERTEX][i])
			arrays[Mesh.ARRAY_NORMAL][i] = transform.basis.xform(arrays[Mesh.ARRAY_NORMAL][i])
		self.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		self.surface_set_material(surface_index, mesh.surface_get_material(surface_index))
