extends Effect


func _on_GunItem_target_hit(target, position, direction, normal):
	var effect = hit_effect.instantiate()
	# TODO: set material_override, albedo_color ff0000 if character
	effect.set_orientation(position, normal)
	var world_scene
	if is_instance_valid(GameManager.game):
		world_scene = GameManager.game.level
	else:
		world_scene = owner.owner_character.owner as Node3D
	
	world_scene.call_deferred("add_child", effect)


func _on_GunItem_on_shoot():
	handle_sound()
	handle_particles()
	handle_flash()
	pass
