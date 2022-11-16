extends EquipmentItem
class_name Rock


export (NodePath) var player_path
export(AttackTypes.Types) var melee_damage_type : int = 0
onready var player=get_node(player_path)
func _ready():
	pass
func _on_Hitbox_hit(other):
	pass



func _on_Hitbox_body_entered(body):
	pass
