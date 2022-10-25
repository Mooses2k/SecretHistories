extends MeleeItem
class_name Mace


export (NodePath) var player_path

onready var player=get_node(player_path)


func _ready():
	pass


func _on_Hitbox_hit(other):
	if can_hit and other.owner != owner_character and other.owner.has_method("damage"):
		other.owner.damage(melee_damage, melee_damage_type, other)


func _on_Hitbox_body_entered(body):
	if body is RigidBody and can_hit==true:
		body.apply_central_impulse(-player.global_transform.basis.z*melee_damage)
