extends Node


var next_scene : NodePath


## Old way
#func _change_to_scene(scene_loc : NodePath) -> void :
#	next_scene = scene_loc
#	var _error = get_tree().change_scene("res://scenes/UI/loadscreen/load_screen.tscn")


func change_to_instance(scene : Node) -> void:
	get_tree().current_scene.queue_free()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
