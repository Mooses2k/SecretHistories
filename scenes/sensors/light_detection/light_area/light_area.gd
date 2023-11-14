tool class_name LightArea extends Area


var collision_shape := CollisionShape.new()
var parent: Light
var shape: Shape


func _init() -> void:
	collision_layer = 1 << 10
	collision_mask = 1 << 10
	priority = 50

func _ready() -> void:
	if !collision_shape.is_inside_tree():
		add_child(collision_shape)
	
	collision_layer = 1 << 10
	collision_mask = 1 << 10
	priority = 50


func _enter_tree() -> void:
	update_shape()


func update_shape() -> void:
	parent = get_parent()
	
	if !is_instance_valid(parent):
		return
	
	global_transform = parent.global_transform
	rotation_degrees.x += 90 # For SpotLights.
	
	if parent is OmniLight:
		if not shape is SphereShape:
			shape = SphereShape.new()
		shape.radius = parent.omni_range
	
	elif parent is SpotLight:
		if not shape is ConeShape:
			shape = ConeShape.new()
		shape.height = parent.spot_range
		shape.radius = parent.spot_range * tan(deg2rad(parent.spot_angle))
	collision_shape.shape = shape


func get_aabb() -> AABB:
	if is_instance_valid(parent) and parent is VisualInstance:
		return parent.get_aabb()
	return AABB()


func check_point(point: Vector3) -> bool: # Returns `true` if the raycast towards the point doesn't collide.
	return get_world().direct_space_state.intersect_ray(global_transform.origin, point, [], 1 << 0).empty()
