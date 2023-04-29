extends ToolItem
class_name CandelabraItem


# eventually this is a tool/container-style item or large object that can be reloaded with candles which are disposable...not that you'd ever care to do that

# function this out better, lots of duplicated lines

var material
var new_material

onready var firelight = $Candle1/FireOrigin/Fire/Light

#var has_ever_been_on = false
var is_lit = true
var burn_time_2 = 0.0
var burn_time_3 = 0.0
var light_timer_base
var light_timer_2
var light_timer_3
var is_depleted_2 : bool = false
var is_depleted_3 : bool = false
var random_number_2_3


func _ready():
	light_timer = $Timer
	print(light_timer)
	if light_timer == null:
		print(self.name)
	self.connect("item_is_dropped", self, "light_dropped")
	light_timer.connect("timeout", self, "light_depleted_copy")
	burn_time = 1000.0
	light_timer.set_wait_time(burn_time)
	light_timer.start()
	
	if $Candle3 != null:
		light_timer_2 = $Timer2
		light_timer_2.connect("timeout", self, "light_depleted_2")
		
		light_timer_3 = $Timer3
		light_timer_3.connect("timeout", self, "light_depleted_3")
		
		burn_time_2 = burn_time
		burn_time_3 = burn_time
		
		light_timer_2.set_wait_time(burn_time_2)
		light_timer_2.start()
		light_timer_3.set_wait_time(burn_time_3)
		light_timer_3.start()
	
	material = $Candle1/MeshInstance.get_surface_material(0)
	new_material = material.duplicate()
	$Candle1/MeshInstance.set_surface_material(0,new_material)
	if $Candle2 != null:
		$Candle2/MeshInstance.set_surface_material(0,new_material)
	if $Candle3 != null:
		$Candle3/MeshInstance.set_surface_material(0,new_material)


#func _process(delta):
##	if is_lit == true:
##		light_timer.pause_mode = false
##	else:
##		light_timer.pause_mode = true
#
#	print(light_timer.time_left)
#	if self.mode == equipped_mode and has_ever_been_on == false:
#			burn_time.start()
#			has_ever_been_on = true
##			firelight.visible = not firelight.visible
#			$AnimationPlayer.play("flicker")
##			$Candle1/FireOrigin/Fire.visible = true
###			$Candle1/MeshInstance.emission_enabled = true
##			if $Candle2 != null:
##				$Candle2/FireOrigin/Fire.visible = true
##			if $Candle3 != null:
##				$Candle3/FireOrigin/Fire.visible = true
##			firelight.visible = true
##			$MeshInstance.cast_shadow = false
#			is_lit = true
#	else:
#		is_lit = false


func light():
	if not is_depleted:
		$AnimationPlayer.play("flicker")
		$LightSound.play()
		$Candle1/FireOrigin/Fire.visible = not $Candle1/FireOrigin/Fire.visible
		$Candle1/MeshInstance.cast_shadow = false
		$Candle1/MeshInstance.get_surface_material(0).emission_enabled  = not $Candle1/MeshInstance.get_surface_material(0).emission_enabled
		
		if $Candle2 != null and not is_depleted_2:
			$Candle2/FireOrigin/Fire.visible = not $Candle2/FireOrigin/Fire.visible
			$Candle2/MeshInstance.cast_shadow = false
			$Candle2/MeshInstance.get_surface_material(0).emission_enabled  = not $Candle2/MeshInstance.get_surface_material(0).emission_enabled
		
		if $Candle3 != null and not is_depleted_3:
			$Candle3/FireOrigin/Fire.visible = not $Candle3/FireOrigin/Fire.visible
			$Candle3/MeshInstance.cast_shadow = false
			$Candle3/MeshInstance.get_surface_material(0).emission_enabled  = not $Candle3/MeshInstance.get_surface_material(0).emission_enabled
		firelight.visible = true
		$MeshInstance.cast_shadow = false
		
		is_lit = true
		light_timer.set_wait_time(burn_time)
		light_timer.start()
		
		if $Candle3 != null:
			light_timer_2.set_wait_time(burn_time_2)
			light_timer_2.start()
			light_timer_3.set_wait_time(burn_time_3)
			light_timer_3.start()


func unlight():
	if not is_depleted:
		$AnimationPlayer.stop()
		$BlowOutSound.play()
		$Candle1/MeshInstance.get_surface_material(0).emission_enabled = false
		$Candle1/FireOrigin/Fire.visible = false
		$Candle1/MeshInstance.cast_shadow = true
		
		if $Candle2 != null and not is_depleted_2:
			unlight_candle_2()
		
		if $Candle3 != null and not is_depleted_3:
			unlight_candle_3()
		
		firelight.visible = false
		$MeshInstance.cast_shadow = true
		
		is_lit = false
		stop_light_timer()


func light_depleted_copy():
	light_depleted()


func _use_primary():
	if is_lit == false:
		light()
	else:
		unlight()


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		switch_away()


func switch_away():
	pass


func stop_light_timer_2():
	burn_time_2 = light_timer_2.get_time_left()
	light_timer_2.stop()


func stop_light_timer_3():
	burn_time_3 = light_timer_3.get_time_left()
	light_timer_3.stop()


func light_depleted_2():
		burn_time_2 = 0
		is_depleted_2 = true
		unlight_candle_2()


func light_depleted_3():
		burn_time_3 = 0
		is_depleted_3 = true
		unlight_candle_3()


func unlight_candle_2():
	$Candle2/FireOrigin/Fire.visible = false
	$Candle2/MeshInstance.get_surface_material(0).emission_enabled = false
	$Candle2/MeshInstance.cast_shadow = true
	stop_light_timer_2()


func unlight_candle_3():
	$Candle3/FireOrigin/Fire.visible = false
	$Candle3/MeshInstance.get_surface_material(0).emission_enabled = false
	$Candle3/MeshInstance.cast_shadow = true
	stop_light_timer_3()


func light_dropped():
	if $Candle3 != null:
		stop_light_timer_2()
		stop_light_timer_3()
	
		burn_time_2 -= (burn_time_2 * life_percentage_lose)
		random_number_2_3 = rand_range(0.0, 1.0)
		light_timer_2.set_wait_time(burn_time_2)
		light_timer_2.start()
		if random_number_2_3 < prob_going_out:
			unlight_candle_2()
		
		burn_time_3 -= (burn_time_3 * life_percentage_lose)
		random_number_2_3 = rand_range(0.0, 1.0)
		light_timer_3.set_wait_time(burn_time_3)
		light_timer_3.start()
		if random_number_2_3 < prob_going_out:
			unlight_candle_3()
