@tool
extends CollisionShape3D
class_name CharacterCollision

@export var hover_height : float= 0.2:
	set(value):
		hover_height = value
		update_collision()

@export var height : float = 1.7:
	set(value):
		height = value
		update_collision()

@export var radius : float = 0.2:
	set(value):
		radius = value
		update_collision()

func update_collision():
	if shape is not CylinderShape3D:
		shape = CylinderShape3D.new()
	var shape_height : float = height - hover_height
	shape.height = shape_height
	shape.radius = radius
	position.y = hover_height + 0.5*shape_height
