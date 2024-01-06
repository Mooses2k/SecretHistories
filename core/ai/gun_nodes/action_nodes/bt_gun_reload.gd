class_name BTReloadGun extends BTAction


# If have appropriate ammo for currently equipped (mainhand) gun, reload it


signal character_reloaded   # For signalling speech


func _tick(state : CharacterState) -> int:
	var inventory = state.character.inventory
	var equipment = state.character.inventory.current_mainhand_equipment as GunItem
	var animation_tree : AnimationTree = $"%AnimationTree"
	var animation_player : AnimationPlayer = $"%AnimationPlayer"
	for ammo_type in equipment.ammo_types:
		if inventory.tiny_items.has(ammo_type) and inventory.tiny_items[ammo_type] > 0:
			if equipment.current_ammo < 1:
				equipment.reload()
				animation_tree.set("parameters/" + str(equipment.item_name) + "/active", true)
				equipment.animation_player.play("reload")
				yield(get_tree().create_timer(equipment.animation_player.get_animation("reload").length), "timeout")
				emit_signal("character_reloaded")
				return BTResult.OK
	return BTResult.FAILED
