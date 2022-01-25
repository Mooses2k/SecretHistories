extends Gun

var can_shoot : bool = true
var pellets = 8

const hit_effect_packed = preload("res://scenes/objects/items/shotgun/hit_effect.tscn")

onready var aimcast : RayCast = $RayCast as RayCast
onready var timer = $RateofFireTimer as Timer

func _ready():
	timer.wait_time = 1.0 / rate_of_fire

func can_shoot() -> bool:
	return can_shoot

func shoot():
	if not can_shoot:
		return

	for p in pellets:
		var shoot_direction = Vector3.FORWARD
		var shoot_dispersion = Vector3.UP.rotated(Vector3.FORWARD, randf()*2*PI)
		shoot_dispersion *= randf()*self.dispersion
		aimcast.look_at(to_global(shoot_direction + shoot_dispersion), Vector3.UP)
		aimcast.force_raycast_update()
		print("Shotgun fired at ", -aimcast.global_transform.basis.z)
		if aimcast.is_colliding():
			var target_hit = aimcast.get_collider()
			if target_hit is Hitbox:
				target_hit.hit(self.damage)
			var effect = hit_effect_packed.instance()
			effect.set_orientation(aimcast.get_collision_point(), aimcast.get_collision_normal())
			call_deferred("add_child", effect)

	can_shoot = false
	timer.start()
	emit_signal("gun_shot")


func _on_RateofFireTimer_timeout():
	can_shoot = true
