extends Node


# warning-ignore:unused_signal
signal scene_loaded

const Loadscreen = preload("res://scenes/ui/loadscreen/load_screen.tscn")
var loadscreen : Node


func setup_loadscreen() -> void:
	loadscreen = Loadscreen.instance()
	get_tree().current_scene.add_child(loadscreen)
	get_tree().paused = true


func remove_loadscreen() -> void:
	loadscreen.queue_free()
	get_tree().paused = false
	AudioSettings.internal_effects_volume = 0.0
	# warning-ignore:return_value_discarded
	get_tree().create_tween()\
		.tween_property(AudioSettings, "internal_effects_volume", 1.0, 4.0)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_IN)


func change_scene(path) -> void:
	get_tree().current_scene.queue_free()
	get_tree().root.add_child(path)
	get_tree().current_scene = path
	
	setup_loadscreen()
