extends Spatial

export var aim_plane : Plane
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
	var intersection_result = aim_plane.intersects_ray(ro, rd)
	if intersection_result:
		self.visible = true
		self.global_transform.origin = intersection_result
		
		# Point player towards this point without rotating (around y?)
		var pos = intersection_result
		var look_at_me = Vector3(pos.x, get_parent().get_node("Body").global_transform.origin.y, pos.z)
		get_parent().get_node("Body").look_at(look_at_me, Vector3.UP)
		
		#Point this node towards the player
		var target_pos : Vector3 = get_parent().global_transform.origin
		target_pos.y = self.global_transform.origin.y
		if (not self.global_transform.origin.is_equal_approx(target_pos)):
			self.look_at(target_pos, Vector3.UP)
	else:
		self.visible = false
		

