extends Interactable


var loop_position : Vector3 setget ,get_loop_position

var current_padlock : PadlockItem = null

signal padlock_added()
signal padlock_removed()
signal padlock_unlocked()


func get_loop_position() -> Vector3:
	return $LoopPosition.translation


func has_padlock() -> bool:
	return current_padlock != null


func is_padlock_locked() -> bool:
	return current_padlock.padlock_locked if current_padlock else false


func try_unlock_padlock(character) -> bool:
	var inventory = character.inventory
	if current_padlock:
		if (not current_padlock.padlock_locked) or inventory.keychain.has(current_padlock.padlock_id):
			current_padlock.padlock_locked = false
			emit_signal("padlock_unlocked")
			return true
	return false


func try_lock_padlock() -> bool:
	if current_padlock and not current_padlock.padlock_locked:
		current_padlock.padlock_locked = true
		return true
	return false


func _interact(character):
	var inventory = character.inventory
	#remove a padlock from the loop
	if has_padlock():
		if try_unlock_padlock(character):
			var padlock = current_padlock
			current_padlock = null
			var picked = inventory.add_item(padlock)
			emit_signal("padlock_removed")
			if not picked:
				padlock.get_parent().remove_child(padlock)
				inventory._drop_item(padlock)
	else: # Add a padlock to the loop
		var padlock_primary = true
		var padlock = inventory.get_mainhand_item() as PadlockItem
		if not padlock or padlock.padlock_locked:
			padlock = inventory.get_offhand_item() as PadlockItem
			padlock_primary = false
		if padlock and not padlock.padlock_locked:
			current_padlock = padlock
			if padlock_primary:
				inventory.drop_mainhand_item()
			else:
				inventory.drop_offhand_item()
			padlock.get_parent().remove_child(padlock)
			add_child(current_padlock)
			padlock.set_physics_equipped()
			update_lock_position()
			emit_signal("padlock_added")


func _physics_process(delta):
	update_lock_position()


func update_lock_position():
	if current_padlock:
		current_padlock.transform = Transform.IDENTITY
		current_padlock.translation = self.loop_position - current_padlock.loop_position
