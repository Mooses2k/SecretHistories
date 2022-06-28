extends Interactable

var loop_position : Vector3 setget ,get_loop_position

signal padlock_added()
signal padlock_removed()
signal padlock_unlocked()

func get_loop_position() -> Vector3:
	return $LoopPosition.translation


var current_padlock : PadlockItem = null

func has_padlock() -> bool:
	return current_padlock != null and is_instance_valid(current_padlock)

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
			yield(current_padlock.drop(current_padlock.global_transform), "completed")
			inventory.add_item(current_padlock)
			emit_signal("padlock_removed")
			current_padlock = null
	else: # Add a padlock to the loop
		if inventory.current_equipment is PadlockItem:
			var padlock : PadlockItem = inventory.current_equipment
			if not padlock.padlock_locked:
				current_padlock = inventory.current_equipment
				inventory.hotbar[inventory.current_slot] = null
				yield(current_padlock.unequip(), "completed")
				inventory.emit_signal("hotbar_changed", inventory.current_slot)
				update_lock_position()
				call_deferred("add_child", current_padlock)
				emit_signal("padlock_added")

func _process(delta):
	update_lock_position()

func update_lock_position():
	if current_padlock:
		current_padlock.transform = Transform.IDENTITY
		current_padlock.translation = self.loop_position - current_padlock.loop_position
