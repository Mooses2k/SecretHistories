extends Area3D

@export var dps = 5.0

func _process(delta):
	for body in self.get_overlapping_bodies():
		if body.is_in_group("CHARACTER"):
			body.damage(dps*delta, AttackTypes.Types.SPECIAL, null)
			if body is Player:
				var player = body as Player
				player.tinnitus.enable()
