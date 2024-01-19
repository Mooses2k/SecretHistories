class_name Hitbox
extends Area3D


# This class represents a generic hitbox
# If this hitbox can initiate interactions with other hitboxes,
# For example, if it belongs to a melee weapon,
# `Monitoring` should be set to true, and false otherwise

# If this hitbox can receive interactions from other hitboxes,
# For example, it it belongs to a character that can be attacked,
# `Monitorable` should be set to true, and false otherwise

# This hitbox collided with another hitbox


signal hit(other)


func _ready():
	connect("area_entered", Callable(self, "on_area_entered"))


func on_area_entered(area):
	# Checks if the other area is also a hitbox
	if area is Hitbox:
		emit_signal("hit", area)
