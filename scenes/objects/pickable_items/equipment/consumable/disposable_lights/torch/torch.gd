class_name TorchItem
extends DisposableLightItem


#var has_ever_been_on = false
signal item_is_dropped

var is_lit = false
var burn_time : float
var is_depleted : bool = false
var is_dropped: bool = false
var is_just_dropped: bool = true
var light_timer
var random_number
export(float, 0.0, 1.0) var life_percentage_lose : float = 0.0
export(float, 0.0, 1.0) var prob_going_out : float = 0.0

onready var firelight = $FireOrigin/Fire/Light


func _ready():
	light_timer = $BurnTime
	light_timer.connect("timeout", self, "light_depleted")
	burn_time = 600.0
#	light_timer.set_wait_time(burn_time)
#	light_timer.start()


func light():
	if not is_depleted:
		$AnimationPlayer.play("flicker")
		$Sounds/LightSound.play()
		$Sounds/Burning.play()
		$FireOrigin/Fire.emitting = true
		$FireOrigin/EmberDrip.emitting = true
		$FireOrigin/Smoke.emitting = true
		firelight.visible = true
		$MeshInstance.cast_shadow = false
		
		is_lit = true
		light_timer.set_wait_time(burn_time)
		light_timer.start()


func unlight():
	if not is_depleted:
		$AnimationPlayer.stop()
		if !is_dropped and burn_time > 0:
			$Sounds/BlowOutSound.play()
		$Sounds/Burning.stop()
		$FireOrigin/Fire.emitting = false
		$FireOrigin/EmberDrip.emitting = false
		$FireOrigin/Smoke.emitting = false
		firelight.visible = false
		$MeshInstance.cast_shadow = true
		
		is_lit = false
		stop_light_timer()


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		switch_away()


func switch_away():
	unlight()


func _use_primary():
	if is_lit == false:
		light()
	else:
		unlight()


func _on_light_depleted():
	burn_time = 0
	unlight()
	is_depleted = true


func stop_light_timer():
	burn_time = light_timer.get_time_left()
	print("current burn time " + str(burn_time))
	light_timer.stop()


func item_drop():
	stop_light_timer()
	burn_time -= (burn_time * life_percentage_lose)
	print("reduced burn time " + str(burn_time))
	random_number = rand_range(0.0, 1.0)
	
	light_timer.set_wait_time(burn_time)
	light_timer.start()
	
	if random_number < prob_going_out:
		unlight()
