class_name CandelabraItem
extends ToolItem

### Eventually this is a tool/container-style item or large object that can be reloaded with candles which are disposable...

# TODO: rework lighting code generally, function this out better, lots of duplicated lines here and in lantern.gd, torch.gd, candle.gd


signal item_dropped
var burn_time : float
var is_depleted : bool = false
var is_dropped: bool = false
var is_just_dropped: bool = true
var light_timer
var random_number
@export var life_percentage_lose : float = 0.0 # (float, 0.0, 1.0)
@export var prob_going_out : float = 0.0 # (float, 0.0, 1.0)

var material
var new_material

@onready var firelight = $Candle1/FireOrigin/Fire/Light3D

var is_lit = true
var burn_time_2 = 0.0
var burn_time_3 = 0.0
@onready var light_timer_base : Node = $Timer
#onready var light_timer_2 : Node = $Timer2   # Doing these in _ready avoids a red debugger error
#onready var light_timer_3 : Node = $Timer3
var is_depleted_2 : bool = false
var is_depleted_3 : bool = false
var random_number_2_3

@export var number_of_candles : int = 1


func _ready():
	light_timer = $Timer
	if light_timer == null:
		print(self.name)
	self.connect("item_is_dropped", Callable(self, "light_dropped")) # this current fails, is bugged
	light_timer.connect("timeout", Callable(self, "light_depleted_copy"))
	burn_time = 1000.0
	light_timer.set_wait_time(burn_time)
	light_timer.start()
	
	material = $Candle1/MeshInstance3D.get_surface_override_material(0)
	new_material = material.duplicate()
	$Candle1/MeshInstance3D.set_surface_override_material(0,new_material)

	if number_of_candles > 1:   # TODO: Switch other parts of this script to use this to avoid red debug errors
		$Candle2/MeshInstance3D.set_surface_override_material(0,new_material)
		$Candle3/MeshInstance3D.set_surface_override_material(0,new_material)
		var light_timer_2 = $Timer2
		light_timer_2.connect("timeout", Callable(self, "light_depleted_2"))
		
		var light_timer_3 = $Timer3
		light_timer_3.connect("timeout", Callable(self, "light_depleted_3"))
		
		burn_time_2 = burn_time
		burn_time_3 = burn_time
		
		light_timer_2.set_wait_time(burn_time_2)
		light_timer_2.start()
		light_timer_3.set_wait_time(burn_time_3)
		light_timer_3.start()


func light():
	if not is_depleted:
		$AnimationPlayer.play("flicker")
		$LightSound.play()
		$Candle1/FireOrigin/Fire.visible = not $Candle1/FireOrigin/Fire.visible
		$Candle1/MeshInstance3D.cast_shadow = false
		$Candle1/MeshInstance3D.get_surface_override_material(0).emission_enabled  = not $Candle1/MeshInstance3D.get_surface_override_material(0).emission_enabled
		firelight.visible = true
		$MeshInstance3D.cast_shadow = false
		
		is_lit = true
		light_timer.set_wait_time(burn_time)
		light_timer.start()
		
		if number_of_candles > 1:
			var light_timer_2 = $Timer2
			var light_timer_3 = $Timer3
			if $Candle2 != null and not is_depleted_2:
				$Candle2/FireOrigin/Fire.visible = not $Candle2/FireOrigin/Fire.visible
				$Candle2/MeshInstance3D.cast_shadow = false
				$Candle2/MeshInstance3D.get_surface_override_material(0).emission_enabled  = not $Candle2/MeshInstance3D.get_surface_override_material(0).emission_enabled
			
			if $Candle3 != null and not is_depleted_3:
				$Candle3/FireOrigin/Fire.visible = not $Candle3/FireOrigin/Fire.visible
				$Candle3/MeshInstance3D.cast_shadow = false
				$Candle3/MeshInstance3D.get_surface_override_material(0).emission_enabled  = not $Candle3/MeshInstance3D.get_surface_override_material(0).emission_enabled
			
			if $Candle3 != null:
				light_timer_2.set_wait_time(burn_time_2)
				light_timer_2.start()
				light_timer_3.set_wait_time(burn_time_3)
				light_timer_3.start()


func unlight():
	if not is_depleted:
		$AnimationPlayer.stop()
		$Candle1/MeshInstance3D.get_surface_override_material(0).emission_enabled = false
		$Candle1/FireOrigin/Fire.visible = false
		$Candle1/MeshInstance3D.cast_shadow = true
		
		if get_node_or_null("Candle2") != null and not is_depleted_2:
			unlight_candle_2()
		
		if get_node_or_null("Candle3") != null and not is_depleted_3:
			unlight_candle_3()
		
		firelight.visible = false
		$MeshInstance3D.cast_shadow = true
		
		is_lit = false
		stop_light_timer()


func light_depleted_copy():
	light_depleted()


func _use_primary():
	if is_lit == false:
		light()
	else:
		unlight()
		$BlowOutSound.play()


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		if is_lit:
			var sound = $BlowOutSound.duplicate()
			GameManager.game.level.add_child(sound)
			sound.global_transform = $BlowOutSound.global_transform
			sound.connect("finished", Callable(sound, "queue_free"))
			sound.play()
		owner_character.inventory.switch_away_from_light(self)
		


func stop_light_timer_2():
	var light_timer_2 = $Timer2
	burn_time_2 = light_timer_2.get_time_left()
	light_timer_2.stop()


func stop_light_timer_3():
	var light_timer_3 = $Timer3
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
	$Candle2/MeshInstance3D.get_surface_override_material(0).emission_enabled = false
	$Candle2/MeshInstance3D.cast_shadow = true
	stop_light_timer_2()


func unlight_candle_3():
	$Candle3/FireOrigin/Fire.visible = false
	$Candle3/MeshInstance3D.get_surface_override_material(0).emission_enabled = false
	$Candle3/MeshInstance3D.cast_shadow = true
	stop_light_timer_3()


func light_dropped():
	print("light_dropped called")
	if number_of_candles > 1:
		var light_timer_2 = $Timer2
		var light_timer_3 = $Timer3
		stop_light_timer_2()
		stop_light_timer_3()
		
		burn_time_2 -= (burn_time_2 * life_percentage_lose)
		random_number_2_3 = randf_range(0.0, 1.0)
		light_timer_2.set_wait_time(burn_time_2)
		light_timer_2.start()
		if random_number_2_3 < prob_going_out:
			unlight_candle_2()
		
		burn_time_3 -= (burn_time_3 * life_percentage_lose)
		random_number_2_3 = randf_range(0.0, 1.0)
		light_timer_3.set_wait_time(burn_time_3)
		light_timer_3.start()
		if random_number_2_3 < prob_going_out:
			unlight_candle_3()


func light_depleted():
	burn_time = 0
	unlight()
	is_depleted = true


func stop_light_timer():
	burn_time = light_timer.get_time_left()
#	print("current burn time " + str(burn_time))
	light_timer.stop()


func item_drop():
	stop_light_timer()
	burn_time -= (burn_time * life_percentage_lose)
	print("reduced burn time " + str(burn_time))
	random_number = randf_range(0.0, 1.0)
	
	light_timer.set_wait_time(burn_time)
	light_timer.start()
	
	print("Linear velocity of candle: ", linear_velocity.length())
	if linear_velocity.length() > 0.1:
		if random_number < prob_going_out:
			unlight()
