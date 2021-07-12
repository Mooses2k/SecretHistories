extends Spatial

var camera_node : Camera

# Called when the node enters the scene tree for the first time.
func _ready():
	camera_node = get_viewport().get_camera()
	set_as_toplevel(true)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var mouse_pos : Vector2 = get_viewport().get_mouse_position()
	var ro : Vector3 = camera_node.project_ray_origin(mouse_pos)
	var rd : Vector3 = camera_node.project_ray_normal(mouse_pos)
	var space : PhysicsDirectSpaceState = PhysicsServer.space_get_direct_state(self.get_world().space)
	var intersection_result : Dictionary = space.intersect_ray(ro, ro + rd*camera_node.far)
	if intersection_result.empty():
		self.visible = false
	else:
		self.visible = true
		self.global_transform.origin = intersection_result.position
		
		# Point player towards this point without rotating (around y?)
		var pos = intersection_result.position
		var look_at_me = Vector3(pos.x, get_parent().get_node("Body").global_transform.origin.y, pos.z)
		get_parent().get_node("Body").look_at(look_at_me, Vector3.UP)

