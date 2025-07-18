extends AudioStreamPlayer3D


func _enter_tree():
	self.play()


func _on_finished():
	var msg := "Drop sound was played by %s at %s"%[get_parent(), global_position]
	if GameManager.game != null and GameManager.game.player != null:
		msg += " with player at"%[GameManager.game.player.global_position]
	print(msg)
	queue_free()
