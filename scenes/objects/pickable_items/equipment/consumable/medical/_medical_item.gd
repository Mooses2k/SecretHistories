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
	print("[DEBUG] _use_reload called on: ", item_name, " (max_charges: ", max_charges_held, ", current_charges: ", charges_held, ")")
	
	# Only works for medical containers (max_charges_held > 1)
	if max_charges_held <= 1:
		print("[DEBUG] Not a container (max_charges_held <= 1), returning")
		return
	
	# Silently fail if already full
	if charges_held >= max_charges_held:
		print("[DEBUG] Container already full, returning")
		return
	
	# Get the owner's inventory
	var inventory = owner_character.inventory
	if inventory == null:
		print("[DEBUG] No inventory found, returning")
		return
	
	print("[DEBUG] Looking for single-use medical items with name: ", item_name)
	
	# Define filter function to find single-use medical items
	var filter_func = func(item):
		var is_medical = item is MedicalItem
		var is_single_use = item.max_charges_held == 1 if is_medical else false
		var has_charges = item.charges_held > 0 if is_medical else false
		print("[DEBUG] Checking item: ", item.name if item != null else "null",
			  " - is_medical: ", is_medical, ", is_single_use: ", is_single_use,
			  ", has_charges: ", has_charges)
		return is_medical and is_single_use and has_charges
	
	# Define action function to consume charges from matching items
	var action_func = func(item, slot_index):
		# Calculate how much space we have left
		var space_left = max_charges_held - charges_held
		if space_left <= 0:
			return  # Container is full

		# Add heal_amount to charges_held (up to max_charges_held)
		var amount_to_add = min(space_left, item.heal_amount)
		charges_held += amount_to_add

		# Consume one unit of the source through the owning inventory's
		# record API: the record is the count truth (T5).
		var record = null
		if item.stack_record_id >= 0:
			record = inventory.get_stack_record(item.stack_record_id)

		if record != null and record.count > 1:
			# Units remain after this one: the node stays as the record's
			# representative.
			inventory.remove_from_stack_record(record.id, 1)
			inventory.emit_signal("hotbar_changed", slot_index)
		else:
			# Last unit: the node itself is consumed. Clear the slot and any
			# hand first so the record's destroy condition holds at the
			# remove. A source without a record is consumed the same way; the
			# encumbrance recount self-heals at the next mutation.
			inventory.hotbar[slot_index] = null
			if inventory.current_mainhand_slot == slot_index:
				inventory.unequip_mainhand_item()
			elif inventory.current_offhand_slot == slot_index:
				inventory.unequip_offhand_item()
			if record != null:
				inventory.remove_from_stack_record(record.id, 1)
			inventory.emit_signal("hotbar_changed", slot_index)
			item.queue_free()

		inventory.emit_signal("inventory_changed")
	
	# Define early termination function to stop when container is full
	var early_termination_func = func(item):
		var is_full = self.charges_held >= self.max_charges_held
		if is_full:
			print("[DEBUG] Container is now full, terminating search")
		return is_full
	
	# Use the search_hotbar utility function
	print("[DEBUG] Starting hotbar search for consumable medical items")
	inventory.search_hotbar(filter_func, action_func, early_termination_func)
	
	# Update UI if needed
	emit_signal("item_data_changed")
	print("[DEBUG] _use_reload completed, final charges: ", charges_held)



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
		# owner_character.drop_consumable(self) has no definition anywhere
		# (Brooks audit 4.2). Consumption goes through the inventory record
		# API (T11).
		if owner_character != null and owner_character.inventory != null:
			_consume_self_through_inventory(owner_character.inventory)
		else:
			queue_free()
		# TODO: this should drop an empty bottle or syringe, only queue_free if nothing's left, like bandage


## Consumes this single-use unit through the owner's record API (T11). When
## the record holds more units, the consumed representative is freed and a
## fresh unit materializes into the same slot and hand; when it was the last
## unit, the slot and any hand are cleared and the record is destroyed.
func _consume_self_through_inventory(inventory) -> void:
	var was_mainhand : bool = inventory.current_mainhand_equipment == self
	var was_offhand : bool = inventory.current_offhand_equipment == self
	var slot_index := -1
	for i in range(inventory.hotbar.size()):
		if inventory.hotbar[i] == self:
			slot_index = i
			break
	var record = null
	if stack_record_id >= 0:
		record = inventory.get_stack_record(stack_record_id)

	if record != null and record.count > 1 and slot_index != -1:
		# Units remain: materialize the next one into the same slot. The
		# materialize decrements the record by one: the consumed unit.
		var next_unit = inventory.materialize_stack_item(record.id)
		if next_unit != null:
			if was_mainhand:
				inventory.unequip_mainhand_item()
			elif was_offhand:
				inventory.unequip_offhand_item()
			inventory.hotbar[slot_index] = next_unit
			inventory.emit_signal("hotbar_changed", slot_index)
			inventory.emit_signal("inventory_changed")
			if was_mainhand:
				inventory.equip_mainhand_item()
			elif was_offhand:
				inventory.equip_offhand_item()
			queue_free()
			return
		# Spawn failed: keep this node as the representative (no-destroy
		# rule); the next use retries.
		push_warning("MedicalItem: materialization failed, the unit stays for a retry")
		return

	# Last unit (or no record): the node itself is consumed. A source without
	# a record is consumed the same way; the encumbrance recount self-heals
	# at the next mutation.
	if slot_index != -1:
		inventory.hotbar[slot_index] = null
	if was_mainhand:
		inventory.unequip_mainhand_item()
	elif was_offhand:
		inventory.unequip_offhand_item()
	if record != null:
		inventory.remove_from_stack_record(record.id, 1)
	if slot_index != -1:
		inventory.emit_signal("hotbar_changed", slot_index)
	inventory.emit_signal("inventory_changed")
	queue_free()
