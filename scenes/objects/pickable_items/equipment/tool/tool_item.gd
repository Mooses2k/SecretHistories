extends EquipmentItem;
class_name ToolItem

signal item_is_dropped
var burn_time : float
var is_depleted : bool = false
var is_dropped: bool = false
var is_just_dropped: bool = true
var light_timer
var random_number
export var is_oil_based : bool = false
export(float, 0.0, 1.0) var life_percentage_lose : float = 0.0
export(float, 0.0, 1.0) var prob_going_out : float = 0.0


func _process(delta):
	if item_state == GlobalConsts.ItemState.DROPPED:
		$ignite/CollisionShape.disabled = false
		is_dropped = true
		
		if is_dropped and not is_just_dropped:
			is_just_dropped = true
			self.emit_signal("item_is_dropped")
			item_drop()
	else:
		$ignite/CollisionShape.disabled = true
		is_dropped = false
		is_just_dropped = false


func light():
	pass


func unlight():
	pass


func light_depleted():
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
