extends MeleeItem
class_name SabreItem


func _on_Hitbox_hit(other):
	if can_hit and other.owner != owner_character and other.owner.has_method("damage"):
		other.owner.damage(melee_damage, melee_damage_type, other)
