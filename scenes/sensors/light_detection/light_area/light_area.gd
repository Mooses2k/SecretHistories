@tool 
class_name LightArea extends Area3D


var collision_shape := CollisionShape3D.new()
var parent: Light3D
var shape: Shape3D


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
	
	if parent is OmniLight3D:
		if not shape is SphereShape3D:
			shape = SphereShape3D.new()
		shape.radius = parent.omni_range
	
	elif parent is SpotLight3D:
		if not shape is ConeShape:
			shape = ConeShape.new()
		shape.height = parent.spot_range
		shape.radius = parent.spot_range * tan(deg_to_rad(parent.spot_angle))
	collision_shape.shape = shape


func get_aabb() -> AABB:
	if is_instance_valid(parent) and parent is VisualInstance3D:
		return parent.get_aabb()
	return AABB()


func check_point(point: Vector3) -> bool: # Returns `true` if the raycast towards the point doesn't collide.
	var world := get_world_3d()
	if !is_instance_valid(world): return false
	var params : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		global_transform.origin,
		point,
		1 << 0,
		[]
	)
	return world.direct_space_state.intersect_ray(params).is_empty()
