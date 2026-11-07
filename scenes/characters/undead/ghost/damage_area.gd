extends Area3D

@export var dps = 5.0

func _process(delta):
	for body in self.get_overlapping_bodies():
		if body.is_in_group("CHARACTER"):
			body.damage(dps * delta, GlobalConsts.AttackTypes.SPECIAL)
			# 3.x parity: the ghost's DoT ramps the tinnitus ring while the
			# player stands in the area (strength = frame delta, the same
			# per-frame bump the 3.x player.tinnitus.enable() produced).
			if body is Player:
				Events.tinnitus_triggered.emit(delta)
