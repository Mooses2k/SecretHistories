extends Spatial
class_name Gun

signal gun_shot

export var damage = 0
export var dispersion = 0.0
export var ammunition_type = ""
export var ammunition_capacity = 0
export var rate_of_fire = 0.0

func aim_at(position : Vector3):
	if not self.global_transform.origin.is_equal_approx(position):
		look_at(position, Vector3.UP)


func shoot():
	pass

func can_shoot() -> bool:
	return false
