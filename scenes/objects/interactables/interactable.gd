extends Area
class_name Interactable

signal character_interacted(character)

func interact(character):
	_interact(character)
	emit_signal("character_interacted", character)
	pass

func _interact(character):
	pass
