extends Camera

var screen_width = ProjectSettings.get("display/window/size/width")
var screen_height = ProjectSettings.get("display/window/size/height")
var center = Vector2(screen_width / 2, screen_height / 2)
var ray_origin = Vector3()
var ray_target = Vector3()

export(float, 0.0, 1.0) var shift_intensity : float = 0.5
export var _aim : NodePath
onready var aim : Spatial = get_node(_aim) as Spatial;

func _ready():
	get_viewport().warp_mouse(center)

#TODO: dynamically set limit of camera move away from player - allow more depending on zoom and long-range weapon

func _physics_process(delta):
# This sets up the mouse following the cursor
	pass
	var local_aim = owner.to_local(aim.global_transform.origin)*shift_intensity
	self.translation.x = local_aim.x/2
	self.translation.z = local_aim.z/2
#	var mouse_position = (get_viewport().get_mouse_position())
#
#	mouse_position.x -= get_viewport().size.x / 2
#	mouse_position.y -= get_viewport().size.y / 2
#
#	mouse_position /=  90  # So it doesn't move crazy distances per pixel
#	h_offset = mouse_position.x
#	v_offset = -mouse_position.y

