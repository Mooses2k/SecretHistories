extends Control


func _process(delta: float) -> void:
	self.size = get_viewport().size/VideoSettings.gui_scale
