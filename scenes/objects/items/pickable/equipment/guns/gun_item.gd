extends EquipmentItem
class_name GunItem

export(Array, Resource) var ammo_types
signal on_shoot()

#Override this function to implement shooting functionality
func _shoot():
	pass

func shoot():
	_shoot()
	emit_signal("on_shoot")
	pass

