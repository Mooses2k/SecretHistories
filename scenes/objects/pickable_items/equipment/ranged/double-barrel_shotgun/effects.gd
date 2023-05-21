extends Effect


func _on_GunItem_target_hit(target, position, direction, normal):
	var effect = hit_effect.instance()
	effect.set_orientation(position, normal)
	if GameManager.game:   # this is here so test worlds work
		GameManager.game.level.call_deferred("add_child", effect)


func _on_GunItem_on_shoot():
	handle_sound()
	handle_particles()
	handle_flash()
	pass
