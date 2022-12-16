extends Effect


func _on_RevolverItem_target_hit(target, position, direction, normal):
	var effect = hit_effect.instance()
	effect.set_orientation(position, normal)
	GameManager.game.level.call_deferred("add_child", effect)


func _on_RevolverItem_on_shoot():
	handle_sound()
	handle_particles()
	handle_flash()
	pass
