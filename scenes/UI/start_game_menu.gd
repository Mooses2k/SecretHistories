extends Control


const GAME_SCENE = preload("res://scenes/core/game.tscn")

var game : Game


func _ready() -> void:
	game = GAME_SCENE.instance()
	$"%StartGameSettings".attach_settings(game.get_node("%LocalSettings"))
	$"%SettingsUI".attach_settings(game.get_node("%LocalSettings"))
	pass # Replace with function body.


func _input(event):
	if event.is_action_pressed("fullscreen"):
		VideoSettings.set_fullscreen_enabled(!VideoSettings.is_fullscreen_enabled())


func _on_ZombieSpawnChance_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_CultistSpawnChance_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_GhostDetectionRange_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_StartGame_pressed() -> void:
	GameManager.is_player_dead = false
	ChangeScene.change_to_instance(game)
	# ChangeScene._change_to_scene("res://scenes/core/game.tscn")


func _on_ReturnButton_pressed() -> void:
	var _error = get_tree().change_scene("res://scenes/UI/title_menu.tscn")
