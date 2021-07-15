extends KinematicBody

var speed = 3
var sprint_speed = 6
var current_speed = 0
var velocity = Vector3()

var item_in_main_hand = "shotgun"
var offhand_item = "lantern"
var damage = 100

onready var aimcast = $Body/FPSCamera/AimCast
onready var gun = $Body/Shotgun     # $Body/Pistol
onready var aimpoint = $PlayerAimPoint

func _process(delta):
	
	velocity = Vector3()
	
	gun.aim_at(aimpoint.global_transform.origin)
	
	if Input.is_action_just_pressed("attack"):
		if gun:
			gun.shoot()

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

	if Input.is_action_just_pressed("inventory_1"):
		pass
		
	if Input.is_action_just_pressed("inventory_3"):
		pass
