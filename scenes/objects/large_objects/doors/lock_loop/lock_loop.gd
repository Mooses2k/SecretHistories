extends Spatial

export var _door : NodePath
export var _pair : NodePath
export var lock_distance : float = 0.1

onready var door = get_node(_door)
onready var pair = get_node(_pair)

func _ready():
	pass
