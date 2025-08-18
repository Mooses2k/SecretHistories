extends Node


func _process(delta):
	if get_tree().paused == true:
		$IndicationSystem.hide()
	else:
		$IndicationSystem.show()
