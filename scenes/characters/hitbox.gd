extends Area
class_name Hitbox

export var hitbox_owner_path : NodePath

onready var character : Character = get_node(hitbox_owner_path) as Character

