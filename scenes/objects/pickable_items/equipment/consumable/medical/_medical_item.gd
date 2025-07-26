class_name MedicalItem
extends ConsumableItem

### For now, if bandage or something, remove it on use and add those HP up to max
### For doctor's bag or dentist's kit, use charges up to HP max, but keep item unless exhausted

### TODO: Eventually move the bag and box to containers


@export var heal_amount : int = 10   # Should probably be 10 for consumables & 1 for containers
@export var speed_boost : int = 0

@export var time_to_use : int = 5
@onready var use_timer = $UseTime

@export var max_charges_held : int = 1
@export var max_charges_usable_at_once = 1
var charges_held : int = 1
var charges_used : int = 0


func _ready():
	use_timer.set_wait_time(time_to_use)
	
	if max_charges_held > 1:   # If a medical container, give it some starting charges
		_set_starting_charges()


func _set_starting_charges():
	charges_held = randi() % (max_charges_held + 1)


func _use_primary():
	# TODO: animation
	# TODO: holding down to use, not just tap
	if owner_character.current_health < owner_character.max_health:
		if use_timer.is_stopped():
			use_timer.start()
			# Add something here to play the prep sound if it exists, wait til finished, then play use sound
			$Sounds/Use.play()


# Reload functionality for medical containers
func _use_reload():
	# Only works for medical containers (max_charges_held > 1)
	if max_charges_held <= 1:
		return
	
	# Silently fail if already full
	if charges_held >= max_charges_held:
		return
	
	# Get the owner's inventory
	var inventory = owner_character.inventory
	if inventory == null:
		return
	
	# Go through hotbar slots from lowest to highest
	for i in range(inventory.hotbar.size()):
		var item = inventory.hotbar[i]
		if item == null:
			continue
			
		# Check if it's a single-use medical item
		if item is MedicalItem and item.max_charges_held == 1:
			# Calculate how much space we have left
			var space_left = max_charges_held - charges_held
			if space_left <= 0:
				break  # Container is full
			
			# Add heal_amount to charges_held (up to max_charges_held)
			var amount_to_add = min(space_left, item.heal_amount)
			charges_held += amount_to_add
			
			# Remove the item from inventory
			if item.stackable_resource != null and item.stackable_resource.items_stacked.size() > 1:
				# Remove one from stack
				item.stackable_resource.items_stacked.remove_at(0)
				# Update the hotbar slot to point to the next item in stack
				var next_item = item.stackable_resource.items_stacked[0]
				next_item.stackable_resource = item.stackable_resource
				inventory.hotbar[i] = next_item
				# Adjust encumbrance when removing from stack
				if item.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM:
					inventory.encumbrance -= 1
				if item.item_size == GlobalConsts.ItemSize.SIZE_BULKY:
					inventory.encumbrance -= 2
			else:
				# Remove single item
				inventory.hotbar[i] = null
				# If this was equipped, unequip it
				if inventory.current_mainhand_slot == i:
					inventory.unequip_mainhand_item()
				elif inventory.current_offhand_slot == i:
					inventory.unequip_offhand_item()
				# Adjust encumbrance when removing single item
				if item.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM:
					inventory.encumbrance -= 1
				if item.item_size == GlobalConsts.ItemSize.SIZE_BULKY:
					inventory.encumbrance -= 2
			
			# Queue the consumed item for removal
			item.queue_free()
			
			# If we're full now, stop processing
			if charges_held >= max_charges_held:
				break
	
	# Update UI if needed
	emit_signal("item_data_changed")



func _on_UseTime_timeout():
	var health_below_max = owner_character.max_health - owner_character.current_health
	print("Health below max: ", health_below_max)
	
	if max_charges_held == 1:
		charges_used = 1
	
	if max_charges_held > 1:   # This is a container for medical consumables
		if health_below_max > charges_held:
			charges_used = charges_held
		else:
			charges_used = health_below_max
		charges_held -= charges_used

	owner_character.heal(charges_used * heal_amount)
	print("Healed ", owner_character, " for ", (charges_used * heal_amount))
	
	# TODO: if speed_boost > 0:
	#	set a timer and give most player actions a bit of haste
	
	$Sounds/UseComplete.play()   # Currently doesn't play due to queue_free below
	
	# This is a single-use consumable, se we're done with it
	if max_charges_held == 1:
		owner_character.drop_consumable(self)
		queue_free()
		# TODO: this should drop an empty bottle or syringe, only queue_free if nothing's left, like bandage
