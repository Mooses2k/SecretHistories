class_name CandleItem
extends DisposableLightItem

# TODO: rework lighting code generally, function this out better, lots of duplicated lines here and in lantern.gd, torch.gd, candelabra.gd


signal item_is_dropped

var is_lit : bool = false
var burn_time : float
var is_depleted : bool = false
#var is_dropped: bool = false
#var is_just_dropped: bool = true
var light_timer : Timer
var random_number : float
@export var life_percentage_lose : float = 0.0 # (float, 0.0, 1.0)
@export var prob_going_out : float = 0.0 # (float, 0.0, 1.0)

var material : Material
var new_material : Material

@onready var firelight = $FireOrigin/Fire/Light3D


func _ready() -> void:
	light_timer = $BurnTime
	self.connect("item_is_dropped", Callable(self, "item_drop"))
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

		# Not audible yet: light noise lands with the hearing restore (ai-direction-design.md item 2).
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
	elif current_state == GlobalConsts.ItemState.DROPPED:
		#is_just_dropped = true
		# Emit only (Brooks audit 4.4): the direct item_drop() call here used to
		# double-apply the burn penalty on top of the item_is_dropped signal.
		self.emit_signal("item_is_dropped")


func _on_light_depleted():
	burn_time = 0
	unlight()
	is_depleted = true


func stop_light_timer():
	if is_instance_valid(light_timer):
		# Sample the remainder only while the timer is actually running:
		# a stopped or never-started timer reports 0, and reading it here
		# clobbered burn_time (a dropped, never-lit candle lost its 3600 s).
		if light_timer.time_left > 0.0:
			burn_time = light_timer.get_time_left()
		light_timer.stop()


func item_drop():
	stop_light_timer()
	burn_time -= (burn_time * life_percentage_lose)
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

	if linear_velocity.length() > 0.001:
		if random_number < prob_going_out:
			unlight()
