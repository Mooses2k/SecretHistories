class_name BehaviorTree
extends Node


export var bt_root : NodePath

onready var _bt_root_node = get_node(bt_root) as BTNode
onready var character = owner


# TODO: maybe multithread this. - Alek
func _process(_delta: float) -> void:
	_bt_root_node.tick(character.character_state)


func _on_character_died() -> void:
	queue_free() # Delete mind, cancelling further planning and speech
