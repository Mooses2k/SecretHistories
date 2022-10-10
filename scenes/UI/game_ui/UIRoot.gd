extends Control

func _process(delta: float) -> void:
	self.rect_size = get_viewport().size/VideoSettings.gui_scale
#	pass
