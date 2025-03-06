class_name CandleItem
extends DisposableLightItem

# TODO: rework lighting code generally, function this out better, lots of duplicated lines here and in lantern.gd, torch.gd, candelabra.gd


signal item_is_dropped

var is_lit = false
var burn_time : float
var is_depleted : bool = false
#var is_dropped: bool = false
#var is_just_dropped: bool = true
@export var light_timer: Timer
var random_number
@export var life_percentage_lose : float = 0.0 # (float, 0.0, 1.0)
@export var prob_going_out : float = 0.0 # (float, 0.0, 1.0)

var material
var new_material

@export var firelight : Light3D


func _ready() -> void:
	self.connect("item_is_dropped", Callable(self, "item_drop"))
	if !light_timer:
		light_timer = $BurnTime
	if !firelight:
		firelight = $FireOrigin/Fire/Light3D
	if not light_timer.is_connected("timeout", Callable(self, "_light_depleted")):
		light_timer.connect("timeout", Callable(self, "_light_depleted"))
	burn_time = 3600.0


func light() -> void:
	if not is_depleted:
		$AnimationPlayer.play("flicker")
		$Sounds/LightSound.play()
		$MeshInstance3D.get_surface_override_material(0).emission_enabled = true
	#	$FireOrigin/Fire.emitting = not $FireOrigin/Fire.emitting
		$FireOrigin/Fire.visible = not $FireOrigin/Fire.visible
		firelight.visible = not firelight.visible
		$FireOrigin.visible = true # related to bugfix #604
		$MeshInstance3D.cast_shadow = false
		
		if owner_character:
			if owner_character.noise_level < 5:
				owner_character.noise_level = 5
		
		is_lit = true
		light_timer.set_wait_time(burn_time)
		light_timer.start()


func unlight() -> void:
	if not is_depleted:
		$AnimationPlayer.stop()
		$MeshInstance3D.get_surface_override_material(0).emission_enabled = false
	#	$FireOrigin/Fire.emitting = false
		$FireOrigin/Fire.visible = false
		firelight.visible = false
		$FireOrigin.visible = false # related to bugfix #604
		$MeshInstance3D.cast_shadow = true
		
		is_lit = false
		stop_light_timer()


func _use_primary() -> void:
	print("Lit state before use_primary: ", is_lit)
	if is_lit == false:
		light()
	else:
		unlight()
		$Sounds/BlowOutSound.play()


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
#		if is_lit:
#			var sound = $Sounds/BlowOutSound.duplicate()
#			GameManager.game.level.add_child(sound)
#			sound.global_transform = $Sounds/BlowOutSound.global_transform
#			sound.connect("finished", sound, "queue_free")
#			sound.play()
		owner_character.inventory.switch_away_from_light(self)
	elif current_state == GlobalConsts.ItemState.DAMAGING:
		#is_just_dropped = true
		self.emit_signal("item_is_dropped")
		item_drop()


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
	random_number = randf_range(0.0, 1.0)
	
	light_timer.set_wait_time(burn_time)
	light_timer.start()
	
	print("Linear velocity of candle: ", linear_velocity.length())
	if linear_velocity.length() > 0.001:
		if random_number < prob_going_out:
			unlight()
			print("Light went out due to being thrown")


func play_blowout_sound() -> void:
	$Sounds/BlowOutSound.play()
