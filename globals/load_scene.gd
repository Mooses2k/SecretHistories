extends Node


# warning-ignore:unused_signal
signal scene_loaded
signal loading_screen_removed

const Loadscreen = preload("res://scenes/ui/loadscreen/load_screen.tscn")
var loadscreen : Node


func setup_loadscreen() -> void:
	loadscreen = Loadscreen.instance()
	get_tree().current_scene.add_child(loadscreen)
	get_tree().paused = true


func remove_loadscreen() -> void:
	get_tree().paused = false
	
	AudioSettings.internal_effects_volume = 0.0
	# warning-ignore:return_value_discarded
	get_tree().create_tween()\
		.tween_property(AudioSettings, "internal_effects_volume", 1.0, 4.0)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_IN)
	
	# Fade-in
	loadscreen.label.visible = false
	loadscreen.quote.visible = false
	get_tree().create_tween()\
		.tween_property(loadscreen.color_rect, "color", Color(0, 0, 0, 0), 3.0)\
		.set_ease(Tween.EASE_IN)
	
	# Disable LeftClick for a moment so player doesn't accidentally shoot or something immediately
	GameManager.game.player.player_controller.no_click_after_load_period = true
	yield(get_tree().create_timer(1), "timeout")   # Possibly 0.5 better?
	GameManager.game.player.player_controller.no_click_after_load_period = false
	
	# Wait another second then kill the loadscreen
	yield(get_tree().create_timer(1), "timeout")
	loadscreen.queue_free()   # Crashes if hit button too many times
	emit_signal("loading_screen_removed")


func change_scene(path) -> void:
	get_tree().current_scene.queue_free()
	get_tree().root.add_child(path)
	get_tree().current_scene = path
	
	setup_loadscreen()
