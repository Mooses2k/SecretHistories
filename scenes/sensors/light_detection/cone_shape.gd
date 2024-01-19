@tool 
class_name ConeShape extends ConvexPolygonShape3D


#|===========================================================================|#
#| Custom ConeShape helper since Godot doesn't implement a cone generator.   |# 
#|===========================================================================|#


@export var segments : = 16: set = set_segments
@export var height   : float: set = set_height
@export var radius   : float: set = set_radius


func set_height(value: float) -> void:
	height = max(value, 0)
	update_shape()


func set_radius(value: float) -> void:
	radius = max(value, 0)
	update_shape()


func set_segments(value: int) -> void:
	segments = int(clamp(value, 3, 128))
	update_shape()


func update_shape() -> void:
	# Add the cone's tip
	var points := PackedVector3Array([Vector3.ZERO])
	
	# Add base circle points
	for i in range(segments):
		var angle = i * 2.0 * PI / segments
		points.append(Vector3(cos(angle) * radius, -height, sin(angle) * radius))
	
	# Register points to polygon.
	set_points(points)

