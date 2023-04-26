extends Node

const LOADSCREEN = preload("res://scenes/UI/loadscreen/load_screen.tscn")
var loadscreen : Node

signal scene_loaded


func _ready() -> void:
	loadscreen = LOADSCREEN.instance()


func setup_loadscreen() -> void:
	get_tree().current_scene.add_child(loadscreen)
	move_child(get_tree().current_scene.get_node("/Loading"), 0)
	get_tree().paused = true


func remove_loadscreen() -> void:
	get_tree().current_scene.remove_child(loadscreen)
	get_tree().paused = false


func change_scene(path) -> void:
#	if (resource != null):
#		get_tree().get_root().call_deferred('add_child', resource.instance())
#		resource = null
#		return
	
	get_tree().current_scene.queue_free()
	get_tree().root.add_child(path)
	get_tree().current_scene = path
	
	setup_loadscreen()
	
#	var loader = ResourceLoader.load_interactive(path)
#	while (true):
#		var res = loader.poll()
#		if res == ERR_FILE_EOF:
#			var resource = loader.get_resource()
#			print("start")
#			break
