extends ToolItem

onready var firelight = $FireOrigin/Fire/Light

func _use():
	firelight.visible = not firelight.visible
	
