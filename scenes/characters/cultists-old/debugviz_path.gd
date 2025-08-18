extends MeshInstance3D

@onready var ai_controller: Node = $"../../AIController"

const OFFSET : Vector3 = Vector3.UP*0.25

func _ready():
	mesh = ImmediateMesh.new()
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var im_mesh : ImmediateMesh = mesh as ImmediateMesh
	if not is_visible_in_tree() or not is_instance_valid(im_mesh):
		return
	im_mesh.clear_surfaces()
	var state = ai_controller.ai_state as CharacterState
	if is_instance_valid(state):
		var path = state.path
		if not path.is_empty():
			im_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			im_mesh.surface_set_color(Color.WHITE)
			im_mesh.surface_add_vertex(owner.global_position + OFFSET)
			for v in path:
				im_mesh.surface_add_vertex(v + OFFSET)
			im_mesh.surface_end()
