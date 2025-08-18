extends Node


const Loadscreen = preload("res://scenes/ui/loadscreen/load_screen.tscn")
var next_scene : String 
var target_node : Node = null
var loading : bool = false
#ONLY used for debug menu
signal loading_screen_removed


##To be used when changing to a different scene (menu to game, game to menu, game to credits, etc)
func change_scene_to_file(path : String) -> void:
	next_scene = path
	loading = true
	get_tree().change_scene_to_packed(Loadscreen)


## To be used when loading an actual level to add to a node
func load_level(path :String, target : Node, load_screen : LoadScreen):
	target_node = target
	next_scene = path
	load_screen.start_loading()


##To be used at the end of loading
func clear_data():
	next_scene = ""
	target_node = null
	
	loading = false
	#Only for debug menu
	loading_screen_removed.emit()
