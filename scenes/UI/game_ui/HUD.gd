extends Control


func exit_state():
	self.visible = false
	pass

func enter_state():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	self.visible = true
	pass
