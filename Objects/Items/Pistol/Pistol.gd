extends Gun

var can_shoot : bool = true

onready var aimcast : RayCast = $RayCast as RayCast
onready var timer = $RateofFireTimer as Timer


func _ready():
	timer.wait_time = 1.0 / rate_of_fire


func shoot():
	if not can_shoot:
		return
	
#	aimcast.rotation.z = rand_range(0, 2 * PI)
#	aimcast.rotation.x = rand_range(0, dispersion)
	aimcast.force_raycast_update()
	
	print("Fired.")
	if aimcast.is_colliding():
		var target_hit = aimcast.get_collider()
		if target_hit is Hitbox:
			print("Hit enemy!")
			target_hit.hitbox_owner.health -= damage

	can_shoot = false
	timer.start()


func _on_RateofFireTimer_timeout():
	can_shoot = true
