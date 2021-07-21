extends Area

export var dps = 5.0



func _process(delta):
	for body in self.get_overlapping_bodies():
		if body is Character:
			body.damage(dps*delta, AttackTypes.Types.SPECIAL)
			if body is Player:
				body.tinnitus.volume_db += 0.3
