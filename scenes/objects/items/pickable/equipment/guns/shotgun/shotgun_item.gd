extends GunItem
class_name ShotgunItem

var on_cooldown : bool = false

func can_shoot():
	return not on_cooldown

func _shoot():
	pass

