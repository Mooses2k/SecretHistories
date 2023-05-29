extends ConsumableItem


#var has_ever_been_on = false
signal item_is_dropped
var is_lit = true
var burn_time : float
var is_depleted : bool = false
var is_dropped: bool = false
var is_just_dropped: bool = true
var light_timer
var random_number
export(float, 0.0, 1.0) var life_percentage_lose : float = 0.0
export(float, 0.0, 1.0) var prob_going_out : float = 0.0

var material
var new_material

onready var firelight = $FireOrigin/Fire/Light


func _ready():
	light_timer = $BurnTime
	light_timer.connect("timeout", self, "light_depleted")
	burn_time = 3600.0
	light_timer.set_wait_time(burn_time)
	light_timer.start()
	
	material = $MeshInstance.get_surface_material(0)
	new_material = material.duplicate()
	$MeshInstance.set_surface_material(0,new_material)


func light():
	if not is_depleted:
		$AnimationPlayer.play("flicker")
		$Sounds/LightSound.play()
	#	$FireOrigin/Fire.emitting = not $FireOrigin/Fire.emitting
		$FireOrigin/Fire.visible = not $FireOrigin/Fire.visible
		firelight.visible = not firelight.visible
		$MeshInstance.cast_shadow = false
		$MeshInstance.get_surface_material(0).emission_enabled  = not $MeshInstance.get_surface_material(0).emission_enabled
		
		is_lit = true
		light_timer.set_wait_time(burn_time)
		light_timer.start()


func unlight():
	if not is_depleted:
		$AnimationPlayer.stop()
		if !is_dropped:
			$Sounds/BlowOutSound.play()
		$MeshInstance.get_surface_material(0).emission_enabled = false
	#	$FireOrigin/Fire.emitting = false
		$FireOrigin/Fire.visible = false
		firelight.visible = false
		$MeshInstance.cast_shadow = true
		
		is_lit = false
		stop_light_timer()


func _use_primary():
	if is_lit == false:
		light()
	else:
		unlight()


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		switch_away()


func switch_away():
	unlight()


func light_depleted():
	burn_time = 0
	unlight()
	is_depleted = true


func stop_light_timer():
	burn_time = light_timer.get_time_left()
	print("current burn time " + str(burn_time))
	light_timer.stop()


# Not working
func item_drop():
	stop_light_timer()
	burn_time -= (burn_time * life_percentage_lose)
	print("reduced burn time " + str(burn_time))
	random_number = rand_range(0.0, 1.0)
	
	light_timer.set_wait_time(burn_time)
	light_timer.start()
	
	if random_number < prob_going_out:
		unlight()
