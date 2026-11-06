class_name TorchItem
extends DisposableLightItem

# TODO: rework lighting code generally, function this out better, lots of duplicated lines here and in lantern.gd, candelabra.gd, candle.gd


signal item_is_dropped

var is_lit : bool = false

var burn_time : float
var is_depleted : bool = false
var is_dropped: bool = false
var is_just_dropped: bool = true
var light_timer : Timer
var random_number : float
@export var life_percentage_lose : float = 0.0 # (float, 0.0, 1.0)
@export var prob_going_out : float = 0.0 # (float, 0.0, 1.0)

@onready var firelight = $FireOrigin/Fire/Light3D


func _ready():
	light_timer = $BurnTime
	burn_time = 600.0


func light():
	if not is_depleted:
		$AnimationPlayer.play("flicker")
		$Sounds/LightSound.play()
		$Sounds/Burning.play()
		$FireOrigin/Fire.emitting = true
		$FireOrigin/EmberDrip.emitting = true
		$FireOrigin/Smoke.emitting = true
		firelight.visible = true
		$FireOrigin.visible = true # related to bugfix #604
		$MeshInstance3D.cast_shadow = false

		if owner_character:
			if owner_character.noise_level < 5:
				owner_character.noise_level = 5

		is_lit = true
		light_timer.set_wait_time(burn_time)
		light_timer.start()


func unlight():
	if not is_depleted:
		$AnimationPlayer.stop()
		$Sounds/Burning.stop()
		$FireOrigin/Fire.emitting = false
		$FireOrigin/EmberDrip.emitting = false
		$FireOrigin/Smoke.emitting = false
		firelight.visible = false
		$FireOrigin.visible = false # related to bugfix #604
		$MeshInstance3D.cast_shadow = true

		is_lit = false
		stop_light_timer()


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
#		if is_lit and burn_time > 0:
#			var sound = $Sounds/BlowOutSound.duplicate()
#			GameManager.game.level.add_child(sound)
#			sound.global_transform = $Sounds/BlowOutSound.global_transform
#			sound.connect("finished", sound, "queue_free")
#			sound.play()
		print("calling switch_away_from_light()")
		owner_character.inventory.switch_away_from_light(self)
	elif current_state == GlobalConsts.ItemState.DROPPED:
		#is_just_dropped = true
		self.emit_signal("item_is_dropped")
		item_drop()


func _use_primary():
	if is_lit == false:
		light()
	else:
		unlight()
		$Sounds/BlowOutSound.play()


func _on_light_depleted():
	burn_time = 0
	unlight()
	is_depleted = true


func stop_light_timer():
	if is_instance_valid(light_timer):
		# Sample the remainder only while the timer is actually running:
		# a stopped or never-started timer reports 0, and reading it here
		# clobbered burn_time (a dropped, never-lit torch lost its 600 s).
		if light_timer.time_left > 0.0:
			burn_time = light_timer.get_time_left()
		light_timer.stop()


func item_drop():
	print("item_drop() in light-source called")
	stop_light_timer()
	burn_time -= (burn_time * life_percentage_lose)
	print("reduced burn time " + str(burn_time))
	random_number = randf_range(0.0, 1.0)

	if is_instance_valid(light_timer):
		# Timer.set_wait_time errors on <= 0 ("Time should be greater than
		# zero"); the 0.1 floor keeps a depleted item's timeout chain intact.
		light_timer.set_wait_time(maxf(burn_time, 0.1))
		# Timer.start errors outside the scene tree; the drop flow calls
		# this between the unequip removal and the re-add to the level
		# (inventory._drop_item sets DROPPED before add_child).
		if is_inside_tree():
			light_timer.start()
		else:
			light_timer.start.call_deferred()
	
	print("Angular velocity of torch: ", angular_velocity.length())
	if angular_velocity.length() > 5:
		if random_number < prob_going_out:
			unlight()
			print("Light went out due to being thrown")
