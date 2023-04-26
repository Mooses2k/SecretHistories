extends Node


func _process(delta):
	if get_tree().paused == true:
		$Indication_system.hide()
	else:
		$Indication_system.show()
