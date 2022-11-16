extends Effect


func _on_ShotgunItem_target_hit(target, position, direction, normal):
	var effect = hit_effect.instance()
	effect.set_orientation(position, normal)
	GameManager.game.level.call_deferred("add_child", effect)


func _on_ShotgunItem_on_shoot():
	handle_sound()
	handle_particles()
	handle_flash()
	pass
