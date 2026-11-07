class_name BombItem
extends ConsumableItem


@export var radius : int = 5 # meters
#export var fragments = 200 # number of raycasts and/or particles
@export var bomb_damage : float #amount of damage to be registered
@export var damage_type : int = 0 # (GlobalConsts.AttackTypes)

var countdown_started : bool = false

var fuse_sound : Node

@onready var countdown_timer : Timer = $Countdown
@onready var flash = $Flash


func _ready():
	super._ready()
	# Connect to tree_exiting signal to notify inventory when bomb is destroyed
	tree_exiting.connect(_on_tree_exiting)


func _process(delta):
	pass


# Add a small delay to prevent rapid successive calls
var last_use_time = 0.0
var use_cooldown = 0.2  # 200ms cooldown

func _use_primary():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_use_time < use_cooldown:
		return
	
	last_use_time = current_time
	
	# If the bomb hasn't been lit yet, light it
	# Otherwise, throw it
	if !countdown_started:
		light()
	else:
		throw()


func light():
	# The equip flow sets EQUIPPED before the item re-enters the tree, so the
	# @onready timer can still be null here; guard instead of erroring.
	if countdown_timer:
		countdown_timer.start()
		countdown_timer.set_paused(false)
	countdown_started = true

	# Safely access Fuse node - it may not exist in base bomb scene
	if has_node("Fuse"):
		$Fuse.emitting = true
	if fuse_sound:
		fuse_sound.play()


func unlight():
	if countdown_timer:
		countdown_timer.set_paused(true)
	# Safely access Fuse node - it may not exist in base bomb scene
	if has_node("Fuse"):
		$Fuse.emitting = false
	if fuse_sound:
		fuse_sound.stop()


func throw():
	if owner_character is Player:
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
		# If it blows up in hand
		if owner_character.is_in_group("CHARACTER") and item_state == GlobalConsts.ItemState.EQUIPPED:
			# dev4 damage entry is the Hurtbox (Hurtbox.damage -> State ->
			# durability). HumanoidCharacter has no damage() method, so the
			# old direct call was a per-explosion script error applying zero
			# damage. Full bomb_damage magnitude is preserved; the first
			# hurtbox is enough since durability is shared via State.
			var hurtboxes := owner_character.find_children("*", "Hurtbox", true, false)
			if hurtboxes.is_empty():
				push_warning("Bomb explosion: owner character has no Hurtbox, self-damage skipped")
			else:
				var hurtbox := hurtboxes[0] as Hurtbox
				hurtbox.damage(floori(bomb_damage), damage_type)
		
		# Camera shake, untested
		#if owner_character.is_in_group("PLAYER") and $Explosion/BlastRadius.get_overlapping_bodies().has(owner_character):
			#owner_character.fps_camera.add_stress(0.5)   # Eventually maybe based on distance from explosion
	
	# The exploding bomb consumes its own unit through the owning inventory's
	# record API (T7), but the bomb is NOT freed this frame: the explosion
	# particles just started emitting and need frames to render. explosions.gd
	# frees the owner after the blast; the tree-exit cleanup then clears the
	# hotbar slot and hands, so the emptied record is destroyed at the next
	# mutation. A thrown bomb already left the inventory through the drop.
	if is_instance_valid(owner_character) and owner_character.inventory != null and stack_record_id >= 0:
		owner_character.inventory.remove_from_stack_record(stack_record_id, 1)


func _on_tree_exiting():
	# Notify inventory that this item is being destroyed.
	# inventory is a node property, not a method, so has_method("inventory")
	# was always false and this cleanup never ran (Brooks audit 4.5).
	if is_instance_valid(owner_character) and owner_character.inventory != null:
		var inventory = owner_character.inventory
		# Null the hotbar slot through the inventory API, not a direct write
		inventory.clear_hotbar_slot_of(self)
		if inventory.current_mainhand_equipment == self:
			inventory.current_mainhand_equipment = null
		elif inventory.current_offhand_equipment == self:
			inventory.current_offhand_equipment = null


func _on_flash_timer_timeout():
	flash.visible = false


func _on_item_state_changed(previous_state, current_state):
	# Only unlight the bomb if it's not already counting down
	# This prevents the bomb from being paused when moved between inventory slots
	if !countdown_started:
		if current_state == GlobalConsts.ItemState.INVENTORY:
			unlight()
		if current_state == GlobalConsts.ItemState.EQUIPPED: # because inv may remove from tree before we can unlight, make sure to unlight it here
			unlight()
	else:
		pass
