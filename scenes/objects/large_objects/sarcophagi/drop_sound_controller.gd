extends AudioStreamPlayer3D


func _enter_tree():
	self.play()


func _on_Spatial_finished():
	get_parent().remove_child(self)
