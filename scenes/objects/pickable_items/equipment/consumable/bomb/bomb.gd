class_name BombItem
extends ConsumableItem


@export var radius = 5 # meters
#export var fragments = 200 # number of raycasts and/or particles
@export var bomb_damage : float #amount of damage to be registered
@export var damage_type : int = 0 # (GlobalConsts.AttackTypes)

var countdown_started = false

var fuse_sound : Node

var throwing = false

@onready var countdown_timer : Timer = $Countdown
@onready var flash = $Flash


func _process(delta):
	# This is here instead of directly under throw() just due to requiring delta
	if throwing == true:
		owner_character.player_controller.throw_state = owner_character.player_controller.ThrowState.SHOULD_THROW
		owner_character.player_controller.update_throw_state(self, delta)
		throwing = false


func _use_primary():
	if countdown_timer.is_stopped() or countdown_timer.is_paused():
		light()
	else:
		throw()


func light():
	if !countdown_started:
		print("Starting countdown")
		countdown_timer.start()
		countdown_started = true
	elif countdown_timer.is_paused():
		countdown_timer.set_paused(false)
		print("Fuse burn time left: ", countdown_timer.time_left)
	
	$Fuse.emitting = true
	if fuse_sound:
		fuse_sound.play()


func unlight():
	countdown_timer.set_paused(true)
	print("Countdown timer paused: ", countdown_timer.is_paused())
	$Fuse.emitting = false
	if fuse_sound:
		fuse_sound.stop()


func throw():
	print("Trying to throw bomb")
	if owner_character is Player:
		throwing = true
		print("Player is the one trying to throw")


func _on_Countdown_timeout():
	item_max_noise_level = 80
	noise_level = 80   # Noise detectable by characters
	flash.get_node("FlashTimer").start()
	flash.visible = true
	$Effect.handle_sound()
	$Explosion.emitting = true
	$Shrapnel.emitting = true
	$Fuse.emitting = false
	$MeshInstance3D.visible = false
	$Explosion._on_Bomb_explosion()
	
	if is_instance_valid(owner_character):
		# If it blows up in hand
		if owner_character.is_in_group("CHARACTER") and item_state == GlobalConsts.ItemState.EQUIPPED:
	#		print("Bomb blew up in ", owner_character, "'s hand for ", fragments / 4 * bomb_damage, " damage.")
			owner_character.damage(bomb_damage, damage_type) # TODO: fix bomb blowing up in character's hand
			throwing = true
		
		# Camera shake, untested
		if owner_character.is_in_group("PLAYER") and $Explosion/BlastRadius.get_overlapping_bodies().has(owner_character):
			owner_character.fps_camera.add_stress(0.5)   # Eventually maybe based on distance from explosion
	
	print("Bomb boomed")


func _on_flash_timer_timeout():
	flash.visible = false


func _on_item_state_changed(previous_state, current_state):
	print("reached on item state changed, current state is: ", current_state)
	if current_state == GlobalConsts.ItemState.INVENTORY:
		print("trying to unlight")
		unlight()
	if current_state == GlobalConsts.ItemState.EQUIPPED: # because inv may remove from tree before we can unlight, make sure to unlight it here
		print("trying to unlight")
		unlight()
