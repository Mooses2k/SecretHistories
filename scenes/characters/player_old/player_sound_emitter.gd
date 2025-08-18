class_name PlayerSoundEmitter
extends Area3D


var radius = 1.0


func _process(_delta):
	if not $CollisionShape3D.shape is SphereShape3D:
		$CollisionShape3D.shape = SphereShape3D.new()
	
	for body in get_overlapping_bodies():
		if body.has_method("listen"):
			body.listen(get_parent())
	
	if $CollisionShape3D.shape:
		$CollisionShape3D.shape.radius = radius
