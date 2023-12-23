extends Effect


func _on_GunItem_target_hit(target, position, direction, normal):
	var effect = hit_effect.instance()
	effect.set_orientation(position, normal)
	var world_scene
	if is_instance_valid(GameManager.game):
		world_scene = GameManager.game.level
	else:
		world_scene = owner.owner_character.owner as Spatial
	
	world_scene.call_deferred("add_child", effect)

# audiostream thing with unit_db to make this louder than the rifle
func _on_GunItem_on_shoot():
	handle_sound()
	handle_particles()
	handle_flash()
	pass
