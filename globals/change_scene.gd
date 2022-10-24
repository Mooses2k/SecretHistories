extends Node

var next_scene : NodePath

func _change_to_scene(scene_loc : NodePath) -> void :
	next_scene = scene_loc
	var _error = get_tree().change_scene("res://scenes/UI/loadscreen/load_screen.tscn")
