extends MeleeItem
class_name Shovel


export (NodePath) var player_path

onready var player=get_node(player_path)


func _ready():
	pass


func _on_Hitbox_hit(other):
	pass


func _on_Hitbox_body_entered(body):
	pass
