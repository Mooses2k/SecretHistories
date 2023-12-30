class_name CandleItem
extends DisposableLightItem

# TODO: rework lighting code generally, function this out better, lots of duplicated lines here and in lantern.gd, torch.gd, candelabra.gd


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

var material
var new_material

onready var firelight = $FireOrigin/Fire/Light


func _ready():
	light_timer = $BurnTime
	self.connect("item_is_dropped", self, "item_drop")
	if not light_timer.is_connected("timeout", self, "_light_depleted"):
		light_timer.connect("timeout", self, "_light_depleted")
	burn_time = 3600.0
	light()


func _process(delta):
	if item_state == GlobalConsts.ItemState.DROPPED:
		$Ignite/CollisionShape.disabled = false
		is_dropped = true
		
		if is_dropped and not is_just_dropped:
			is_just_dropped = true
			self.emit_signal("item_is_dropped")
			item_drop()
	
	else:
		$Ignite/CollisionShape.disabled = true
		is_dropped = false
		is_just_dropped = false
		
	# This ensures it's never emissive while off, also, that candles stay lit on level change
	if $MeshInstance.get_surface_material(0).emission_enabled == true and $FireOrigin/Fire.visible == false:
		light()
	
	
	if is_instance_valid(owner_character):
		if Input.is_action_pressed("playerhand|main_use_primary") and owner_character.is_reloading == false:
			use_hold_time += 0.1
			if  use_hold_time >= 0.8:
				if is_lit:
					if self == owner_character.inventory.get_mainhand_item():
						if horizontal_holding:
							owner_character.get_node("%AnimationTree").set("parameters/Hand_Transition/current", 0)
							owner_character.get_node("%AnimationTree").set("parameters/Weapon_states/current", 0)
							owner_character.get_node("%AnimationTree").set("parameters/Hold_Animation/current", 2)
							owner_character.get_node("%AnimationTree").set("parameters/LightSourceHoldTransition/current", 0)
						else:
							owner_character.get_node("%AnimationTree").set("parameters/Hand_Transition/current", 0)
							owner_character.get_node("%AnimationTree").set("parameters/Weapon_states/current", 0)
							owner_character.get_node("%AnimationTree").set("parameters/Hold_Animation/current", 2)
							owner_character.get_node("%AnimationTree").set("parameters/LightSourceHoldTransition/current", 2)
			
		else:
			use_hold_time = 0
			if self == owner_character.inventory.get_mainhand_item():
				if horizontal_holding == true:
					owner_character.get_node("%AnimationTree").set("parameters/Hand_Transition/current", 0)
					owner_character.get_node("%AnimationTree").set("parameters/Weapon_states/current", 0)
					owner_character.get_node("%AnimationTree").set("parameters/Hold_Animation/current", 1)
				else:
					owner_character.get_node("%AnimationTree").set("parameters/Hand_Transition/current", 0)
					owner_character.get_node("%AnimationTree").set("parameters/Weapon_states/current", 0)
					owner_character.get_node("%AnimationTree").set("parameters/Hold_Animation/current", 0)
				
				


func light():
	if not is_depleted:
		$AnimationPlayer.play("flicker")
		$Sounds/LightSound.play()
	#	$FireOrigin/Fire.emitting = not $FireOrigin/Fire.emitting
		$FireOrigin/Fire.visible = not $FireOrigin/Fire.visible
		firelight.visible = not firelight.visible
		$MeshInstance.cast_shadow = false
		$MeshInstance.get_surface_material(0).emission_enabled = true
		
		is_lit = true
		light_timer.set_wait_time(burn_time)
		light_timer.start()


func unlight():
	if not is_depleted:
		$AnimationPlayer.stop()
		$MeshInstance.get_surface_material(0).emission_enabled = false
	#	$FireOrigin/Fire.emitting = false
		$FireOrigin/Fire.visible = false
		firelight.visible = false
		$MeshInstance.cast_shadow = true
		
		is_lit = false
		stop_light_timer()


func _use_primary():
	print("Lit state before use_primary: ", is_lit)
	if is_lit == false:
		light()
#	else:
#		unlight()
#		$Sounds/BlowOutSound.play()


func _on_timer_timeout():
	# This function will be called when the timer reaches the specified hold time
	# Add any logic you want to execute after holding the button for the required time
	print("Button held for ", use_hold_time, " seconds.")
	# Your existing logic here
	if is_lit:
		if self == owner_character.inventory.get_mainhand_item():
			if horizontal_holding:
				# Your existing logic here
				print("Raising light item")


func _item_state_changed(previous_state, current_state):
	if not is_instance_valid(GameManager.game):
		return
	if current_state == GlobalConsts.ItemState.INVENTORY:
		if is_lit:
			var sound = $Sounds/BlowOutSound.duplicate()
			GameManager.game.level.add_child(sound)
			sound.global_transform = $Sounds/BlowOutSound.global_transform
			sound.connect("finished", sound, "queue_free")
			sound.play()
		owner_character.inventory.switch_away_from_light(self)


func _on_light_depleted():
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
	random_number = rand_range(0.0, 1.0)
	
	light_timer.set_wait_time(burn_time)
	light_timer.start()
	
	print("Linear velocity of candle: ", linear_velocity.length())
	if linear_velocity.length() > 0.1:
		if random_number < prob_going_out:
			unlight()
