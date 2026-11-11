extends MeshInstance3D

## Debug aid: draws the navigation adapter's current path as a line strip.
## Read-only copy of the frozen cultists-old helper, re-pointed from the
## CharacterState surface to the HFSM's NavigationAdapter.

@onready var _controller: Node = $"../../AIController"

const OFFSET : Vector3 = Vector3.UP * 0.25


func _ready() -> void:
	mesh = ImmediateMesh.new()


func _process(_delta: float) -> void:
	var im_mesh : ImmediateMesh = mesh as ImmediateMesh
	if not is_visible_in_tree() or not is_instance_valid(im_mesh):
		return
	var navigation: NavigationAdapter = _controller.navigation_adapter
	if navigation == null:
		return
	im_mesh.clear_surfaces()
	var path: Array = navigation.path
	if not path.is_empty():
		im_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		im_mesh.surface_set_color(Color.WHITE)
		im_mesh.surface_add_vertex(owner.global_position + OFFSET)
		for v in path:
			im_mesh.surface_add_vertex(v + OFFSET)
		im_mesh.surface_end()
