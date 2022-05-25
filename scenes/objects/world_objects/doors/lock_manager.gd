extends Node

var is_locked : bool = false setget set_is_locked

func set_is_locked(value : bool) -> void:
	if is_locked != value:
		if value:
			if abs(owner.door_body.rotation.y) > deg2rad(5):
				print("angle too high")
				return
		is_locked = value
		if value:
			print("locked")
			owner.door_lock_count += 1
		else:
			print("unlocked")
			owner.door_lock_count -= 1

func _ready():
	pass


func _on_Interactable_character_interacted(character):
	self.is_locked = !self.is_locked
	pass # Replace with function body.
