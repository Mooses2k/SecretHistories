extends KinematicBody

var max_walk_speed = 4
var max_run_speed = 10
var current_speed = 0
var acceleration = 0.1

var velocity = Vector3()

var grav = 0
var grav_strength = 0.2
var jump_height = 5
var jumping = false
var floor_just = false

func _ready():
	$cam.set_as_toplevel(true)
	
func _input(event):
	if event is InputEventMouseMotion:
		$cam.rotation_degrees.y -= event.relative.x
		$cam/SpringArm.rotation_degrees.x += event.relative.y
		$cam/SpringArm.rotation_degrees.x = clamp($cam/SpringArm.rotation_degrees.x,-80,80)
	
func _process(delta):
	velocity.y = 0
	
	if Input.is_action_pressed("ui_up"):
		rotation.y = lerp_angle(rotation.y,$cam.rotation.y,0.1)
		velocity = transform.basis.z
		if is_on_floor():
			if Input.is_action_pressed("sprint"):
				current_speed = lerp(current_speed,max_run_speed,acceleration)
				$AnimationTree.set("parameters/state/current",2)
			else:
				current_speed = lerp(current_speed,max_walk_speed,acceleration)
				$AnimationTree.set("parameters/state/current",1)
		
	elif Input.is_action_pressed("ui_down"):
		rotation.y = lerp_angle(rotation.y,$cam.rotation.y+deg2rad(180),0.1)
		velocity = transform.basis.z
		if is_on_floor():
			if Input.is_action_pressed("sprint"):
				current_speed = lerp(current_speed,max_run_speed,acceleration)
				$AnimationTree.set("parameters/state/current",2)
			else:
				$AnimationTree.set("parameters/state/current",1)
				current_speed = lerp(current_speed,max_walk_speed,acceleration)
		
	if Input.is_action_pressed("ui_left"):
		rotation.y = lerp_angle(rotation.y,$cam.rotation.y+deg2rad(90),0.1)
		velocity = transform.basis.z
		if is_on_floor():
			if Input.is_action_pressed("sprint"):
				$AnimationTree.set("parameters/state/current",2)
				current_speed = lerp(current_speed,max_run_speed,acceleration)
			else:
				current_speed = lerp(current_speed,max_walk_speed,acceleration)
				$AnimationTree.set("parameters/state/current",1)
		
	elif Input.is_action_pressed("ui_right"):
		rotation.y = lerp_angle(rotation.y,$cam.rotation.y-deg2rad(90),0.1)
		velocity = transform.basis.z
		if is_on_floor():
			if Input.is_action_pressed("sprint"):
				$AnimationTree.set("parameters/state/current",2)
				current_speed = lerp(current_speed,max_run_speed,acceleration)
			else:
				current_speed = lerp(current_speed,max_walk_speed,acceleration)
				$AnimationTree.set("parameters/state/current",1)
		
	if !Input.is_action_pressed("ui_down") and !Input.is_action_pressed("ui_up") and !Input.is_action_pressed("ui_left") and !Input.is_action_pressed("ui_right"):
		current_speed = lerp(current_speed,0,acceleration)
		if is_on_floor():
			$AnimationTree.set("parameters/state/current",0)
		
	velocity = velocity.normalized()*current_speed
	
	if is_on_floor():
		grav = 0
		velocity.y = -10
		if floor_just == false:
			$AnimationTree.set("parameters/land/active",true)
			floor_just = true
	else:
		floor_just = false
		jumping = false
		grav += grav_strength
		$AnimationTree.set("parameters/state/current",3)
		
	if Input.is_action_just_pressed("jump") and is_on_floor() and jumping == false:
		$jump_timer.start()
		$AnimationTree.set("parameters/jump/active",true)
		$AnimationTree.set("parameters/state/current",3)
		jumping = true
		
	velocity.y -= grav
	move_and_slide(velocity,Vector3.UP)
	$cam.global_transform.origin = global_transform.origin


func _on_jump_timer_timeout():
	grav = -jump_height
	velocity.y = 0
	move_and_slide(velocity,Vector3.UP)
