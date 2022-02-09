extends Spatial
class_name Gun

signal gun_shot


export var ammunition_types = Array()
export var ammunition_capacity = 0
export var reload_ammount = 0

export var damage_offset = 0
export var rate_of_fire = 1.0
export var reload_time = 1.0


func aim_at(position : Vector3):
	if not self.global_transform.origin.is_equal_approx(position):
		look_at(position, Vector3.UP)

func shoot():
	pass

func can_shoot() -> bool:
	return false
