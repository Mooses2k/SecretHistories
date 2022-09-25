extends ToolItem

onready var firelight = $FireOrigin/Fire/Light

func _use_primary():
	firelight.visible = not firelight.visible
	
