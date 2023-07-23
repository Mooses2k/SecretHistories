class_name Hitbox
extends Area


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
	connect("area_entered", self, "on_area_entered")


func on_area_entered(area):
	# Checks if the other area is also a hitbox
	if area is get_script():
		emit_signal("hit", area)
		
		

func _on_Hitbox_body_entered(body):
	if body is PickableItem and body.can_throw_damage and body.from_character != get_parent():
		body.can_throw_damage = false
		body.melee_damage_type
		print("Pickable item can damage")
		print("Hitbox item damage is: ", abs(body.throw_momentum.z))
		print("Hitbox item melee_damage is: ", body.melee_damage_type)
		get_parent().damage(body.throw_momentum.z, body.melee_damage_type, get_parent())
