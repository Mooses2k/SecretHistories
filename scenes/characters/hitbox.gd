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
		var item_damage = int(abs(body.linear_velocity.z)) * int(body.mass) 
		print(body.item_name," melee_damage value is: ", item_damage)
		get_parent().damage(item_damage, body.melee_damage_type, get_parent())
