class_name BehaviorTree
extends Node

export var bt_root : NodePath
onready var _bt_root_node = get_node(bt_root) as BT_Node
onready var character : Character = owner as Character

func _physics_process(delta):
	_bt_root_node.tick(character.character_state)
