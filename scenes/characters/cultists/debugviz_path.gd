extends MeshInstance3D

func _ready():
	mesh = ImmediateMesh.new()
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var im_mesh : ImmediateMesh = mesh as ImmediateMesh
	if not is_visible_in_tree() or not is_instance_valid(im_mesh):
		return
	im_mesh.clear()
	var state = owner.character_state as CharacterState
	if is_instance_valid(state):
		var path = state.path
		if not path.is_empty():
			im_mesh.begin(Mesh.PRIMITIVE_LINE_STRIP)
			im_mesh.set_color(Color.WHITE)
			im_mesh.add_vertex(owner.global_position)
			for v in path:
				im_mesh.add_vertex(v)
			im_mesh.end()
