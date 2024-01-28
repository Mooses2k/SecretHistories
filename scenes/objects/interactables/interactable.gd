class_name Interactable
extends Area3D


signal character_interacted(character)


func interact(character):
	_interact(character)
	emit_signal("character_interacted", character)


func _interact(character):
	pass
