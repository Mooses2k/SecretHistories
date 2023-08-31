extends Node


signal scene_loaded   # Ignore yellow editor message; we need this

const Loadscreen = preload("res://scenes/UI/loadscreen/load_screen.tscn")
var loadscreen : Node


func _ready() -> void:
	loadscreen = Loadscreen.instance()


func setup_loadscreen() -> void:
	get_tree().current_scene.add_child(loadscreen)
	move_child(get_tree().current_scene.get_node("Loading"), 0)    # This here for a reason? Just errors
	get_tree().paused = true


func remove_loadscreen() -> void:
	get_tree().current_scene.remove_child(loadscreen)
	get_tree().paused = false
	AudioSettings.internal_effects_volume = 0.0
	get_tree().create_tween()\
		.tween_property(AudioSettings, "internal_effects_volume", 1.0, 4.0)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_IN)


func change_scene(path) -> void:
	get_tree().current_scene.queue_free()
	get_tree().root.add_child(path)
	get_tree().current_scene = path
	
	setup_loadscreen()
