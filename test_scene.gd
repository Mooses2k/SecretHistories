extends Node


func _ready() -> void:
	var res = load("res://resources/items/ammunition/22.tres")
	print(var2str(inst2dict(res)))
	pass
