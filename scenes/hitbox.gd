# An area that can detect hurtboxes (usually to damage them)
@tool
class_name Hitbox
extends Area3D



# This hitbox collided with a hurtbox
signal hit(hurtbox : Hurtbox)


func _ready():
	connect("area_entered", Callable(self, "on_area_entered"))


func on_area_entered(area):
	if area is Hurtbox:
		emit_signal("hit", area)

func _init() -> void:
	monitoring = true
	monitorable = false

func _property_get_revert(property: StringName) -> Variant:
	match property:
		&"monitoring" : return true
		&"monitorable" : return false
	return null

func _property_can_revert(property: StringName) -> bool:
	match property:
		&"monitoring" : return true
		&"monitorable" : return true
	return false
