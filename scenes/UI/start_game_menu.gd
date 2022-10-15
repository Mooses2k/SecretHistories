extends Control

func _ready() -> void:
	pass # Replace with function body.


func _on_ZombieSpawnChance_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_CultistSpawnChance_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_GhostDetectionRange_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_StartGame_pressed() -> void:
	ChangeScene._change_to_scene("res://scenes/core/game.tscn")

func _on_ReturnButton_pressed() -> void:
	var _error = get_tree().change_scene("res://scenes/UI/title_menu.tscn")
