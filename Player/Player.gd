extends KinematicBody

var speed = 3
var sprint_speed = 6
var current_speed = 0
var velocity = Vector3()

var offhand_item = "lantern"
var damage = 100

onready var aimcast = $Body/BodyMesh/Sunglasses/FPSCamera/AimCast

func _process(delta):
	
	velocity = Vector3()
	
	if Input.is_action_just_pressed("attack"):
		print("Fired.")
		if aimcast.is_colliding():
			var target_hit = aimcast.get_collider()
			if target_hit.is_in_group("Enemy"):
				print("Hit enemy!")
				target_hit.health -= damage
	
	if Input.is_action_pressed("sprint"):
		current_speed = sprint_speed
	else:
		current_speed = speed
	
	if Input.is_action_pressed("move_right"):
		velocity.x += 1
	if Input.is_action_pressed("move_left"):
		velocity.x -= 1
	if Input.is_action_pressed("move_up"):
		velocity.z -= 1
	if Input.is_action_pressed("move_down"):
		velocity.z += 1

	velocity = velocity.normalized() * current_speed

	move_and_slide(velocity)

	if Input.is_action_just_pressed("offhand_use"):
		if offhand_item == "lantern":
			if $Lantern.visible == false:
				$Lantern.visible = true
			else:
				 $Lantern.visible = false
