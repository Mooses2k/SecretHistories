
class_name TinyItem
extends PickableItem


export var item_data : Resource
export var amount : int = 1

func _ready() -> void:
	var player_character : Character = get_parent().owner as Character
	if player_character:
		if "Player" in player_character.name:
			get_node("MeshInstance").layers = 2
