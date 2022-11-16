extends AudioStreamPlayer3D


func _on_AudioStreamPlayer3D_finished():
	queue_free()
