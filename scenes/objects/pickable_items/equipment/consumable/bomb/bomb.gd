class_name BombItem
extends ConsumableItem


@export var radius = 5 # meters
#export var fragments = 200 # number of raycasts and/or particles
@export var bomb_damage : float #amount of damage to be registered
@export var damage_type : int = 0 # (GlobalConsts.AttackTypes)

var countdown_started = false

var fuse_sound : Node

@onready var countdown_timer : Timer = $Countdown
@onready var flash = $Flash


func _ready():
	super._ready()
	# Connect to tree_exiting signal to notify inventory when bomb is destroyed
	tree_exiting.connect(_on_tree_exiting)


func _process(delta):
	if countdown_started:
		print("Countdown timer time_left: ", countdown_timer.time_left)
		print("Countdown timer is_stopped: ", countdown_timer.is_stopped())
		print("Countdown timer is_paused: ", countdown_timer.is_paused())


# Add a small delay to prevent rapid successive calls
var last_use_time = 0.0
var use_cooldown = 0.2  # 200ms cooldown

func _use_primary():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_use_time < use_cooldown:
		print("Bomb use is on cooldown, ignoring input")
		return
	
	last_use_time = current_time
	
	# If the bomb hasn't been lit yet, light it
	# Otherwise, throw it
	if !countdown_started:
		light()
	else:
		throw()


func light():
	print("Starting countdown")
	countdown_timer.start()
	countdown_timer.set_paused(false)
	countdown_started = true
	print("Countdown timer started, time left: ", countdown_timer.time_left)
	print("Countdown timer is_stopped: ", countdown_timer.is_stopped())
	print("Countdown timer is_paused: ", countdown_timer.is_paused())
	
	# Safely access Fuse node - it may not exist in base bomb scene
	if has_node("Fuse"):
		$Fuse.emitting = true
	if fuse_sound:
		fuse_sound.play()


func unlight():
	countdown_timer.set_paused(true)
	print("Countdown timer paused: ", countdown_timer.is_paused())
	print("Countdown timer time_left when paused: ", countdown_timer.time_left)
	# Safely access Fuse node - it may not exist in base bomb scene
	if has_node("Fuse"):
		$Fuse.emitting = false
	if fuse_sound:
		fuse_sound.stop()


func throw():
	print("Trying to throw bomb")
	if owner_character is Player:
		print("Player is the one trying to throw")
		# Don't stop the countdown timer when throwing - let it continue
		# The bomb should explode when the timer completes, whether in hand or thrown
		# Make sure the bomb is still lit when throwing
		if !countdown_started:
			light()
		
		# Use the player controller's throw_object method which handles inventory properly
		# This will call drop_mainhand_item/drop_offhand_item which handles stack re-equipping
		if owner_character.has_node("PlayerController"):
			var player_controller = owner_character.get_node("PlayerController")
			player_controller.throw_object(self)


func _on_Countdown_timeout():
	print("Countdown timer finished, exploding bomb")
	print("[DEBUG] Bomb explosion - owner_character: ", owner_character, " item_state: ", item_state)
	item_max_noise_level = 80
	noise_level = 80   # Noise detectable by characters
	flash.get_node("FlashTimer").start()
	flash.visible = true
	$Effect.handle_sound()
	$Explosion.emitting = true
	$Shrapnel.emitting = true
	# Safely access Fuse node - it may not exist in base bomb scene
	if has_node("Fuse"):
		$Fuse.emitting = false
	$MeshInstance3D.visible = false
	$Explosion._on_Bomb_explosion()
	
	if is_instance_valid(owner_character):
		print("[DEBUG] Bomb explosion - owner_character is valid")
		# If it blows up in hand
		if owner_character.is_in_group("CHARACTER") and item_state == GlobalConsts.ItemState.EQUIPPED:
			print("Bomb blew up in ", owner_character, "'s hand for ", bomb_damage, " damage.")
			owner_character.damage(bomb_damage, damage_type)  ## TODO: implement after new damage rework
		
		# Camera shake, untested
		#if owner_character.is_in_group("PLAYER") and $Explosion/BlastRadius.get_overlapping_bodies().has(owner_character):
			#owner_character.fps_camera.add_stress(0.5)   # Eventually maybe based on distance from explosion
	else:
		print("[DEBUG] Bomb explosion - owner_character is NOT valid")
	
	print("Bomb boomed")
	print("[DEBUG] Bomb explosion complete, calling queue_free()")
	
	# Remove this bomb from its stackable resource before freeing
	if stackable_resource != null:
		print("[DEBUG] Removing bomb from stackable resource")
		stackable_resource.remove_item(self)
	
	queue_free()


func _on_tree_exiting():
	print("[DEBUG] Bomb is being removed from tree, notifying inventory")
	# Notify inventory that this item is being destroyed
	if owner_character and owner_character.has_method("inventory"):
		var inventory = owner_character.inventory
		if inventory and inventory.current_mainhand_equipment == self:
			print("[DEBUG] Clearing inventory reference to this bomb")
			inventory.current_mainhand_equipment = null
		elif inventory and inventory.current_offhand_equipment == self:
			print("[DEBUG] Clearing offhand inventory reference to this bomb")
			inventory.current_offhand_equipment = null


func _on_flash_timer_timeout():
	flash.visible = false


func _on_item_state_changed(previous_state, current_state):
	print("reached on item state changed, current state is: ", current_state)
	# Only unlight the bomb if it's not already counting down
	# This prevents the bomb from being paused when moved between inventory slots
	if !countdown_started:
		if current_state == GlobalConsts.ItemState.INVENTORY:
			print("trying to unlight")
			unlight()
		if current_state == GlobalConsts.ItemState.EQUIPPED: # because inv may remove from tree before we can unlight, make sure to unlight it here
			print("trying to unlight")
			unlight()
	else:
		print("Bomb is already lit, not unlighting when changing states")
