class_name Inventory
extends Node


enum HandEnum {
	MAIN_HAND,
	OFF_HAND
}

## Emmited when the bulky item has changed
signal bulky_item_changed()

## Emitted when a hotbar slot changes (item added or removed), it needs a reference for what slot has changed
signal hotbar_changed(slot)

## Emitted when the user selects a new slot for the main hand
signal mainhand_slot_changed(previous, current)

## Emitted when the user selects a new slot for the offhand
signal offhand_slot_changed(previous, current)

## Emitted when the ammount of a tiny item changes
signal tiny_item_changed(item, previous_amount, curent_amount)

## Emitted to fadein the HUD UI
signal inventory_changed

## Emitted to hide the HUD UI when player dies
signal player_died

## Emmited when the mainhand item was unequipped
signal unequip_mainhand

## Emmited when the offhand item was unequipped
signal unequip_offhand

## 0 is the first slot (1), 10 is the empty_hands slot
const HOTBAR_SIZE : int = 11

# Items tracked exclusively by amount, don't contribute to weight,
# don't show in hotbar
var tiny_items : Dictionary

# Tiny item types the player has picked up at least once, used by the HUD
# ammo readout to list types even when their current amount is zero
var known_tiny_items : Dictionary

# Dictionary of {int : int}, where the key is the key_id and the value is the amount of keys owned
# with that ID
var keychain : Dictionary

# Usable items that appear in the hotbar, as an array of nodes
var hotbar : Array[Node3D]

# One record per stack this inventory owns (see StackableStackRecord). Only
# the stack record API below may create, mutate or destroy entries.
var stack_records : Array[StackableStackRecord] = []

# Monotonic counter handing out stable stack record ids.
var _next_stack_record_id : int = 0

# Stack type id (StackableResource res:// path) per item scene path, so the
# identity walk runs once per scene instead of once per pickup.
var _stack_type_id_cache : Dictionary = {}

# Holder of the hands_free slot number
const hands_free_slot: int = 10

# A special kind of equipment, overrides the hotbar items, cannot be stored
var bulky_equipment : EquipmentItem = null

# Information about the item equipped on the main hand
var current_mainhand_slot : int = 0: set = set_mainhand_slot
var current_mainhand_equipment : EquipmentItem = null

# Information about the item equipped on the offhand
var current_offhand_slot : int = 0: set = set_offhand_slot
var current_offhand_equipment : EquipmentItem = null

# Are we currently in the middle of swapping hands?
var are_swapping : bool = false

var encumbrance : float = 0   # Is a float to allow easy division

var belt_item = null   # The item currently in the belt_position slot

@onready var character : HumanoidCharacter = owner as HumanoidCharacter


func _ready():
	hotbar.resize(HOTBAR_SIZE)
	current_offhand_slot = hands_free_slot


## Returns whether a given node can be added as an Item to this inventory
## Consolidated validation function that includes all pickup checks
func can_pickup_item(item: PickableItem) -> bool:
	# Can only pickup dropped items
	# (may change later to steal weapons, or we can do that by dropping them first)
	# Also prevents picking up busy items

	# Null check with error logging
	if item == null:
		push_error("can_pickup_item: Item is null, cannot pick up")
		return false

	assert(item != null, "Item should not be null at this point")

	# Check if item is in a valid state for pickup
	if not (item.item_state == GlobalConsts.ItemState.DROPPED):
		return false

	# Check if item type is valid for pickup
	if not ((item is EquipmentItem) or (item is TinyItem) or (item is KeyItem)):
		return false

	return true


## Handles TinyItem and KeyItem processing
## Returns true if item was processed as tiny/key item, false if not applicable
func handle_tiny_items(item: PickableItem) -> bool:
	assert(item != null, "Item should not be null in handle_tiny_items")

	if item is TinyItem:
		if item.item_data == null:
			push_error("TinyItem has null item_data: ", item.name)
			return false

		insert_tiny_item(item.item_data, item.amount)

		# Play pickup sound before destroying the item
		if item.has_method("play_pickup_sound"):
			item.play_pickup_sound()

		# To make sure the item can't be interacted with again
		item.set_item_state(GlobalConsts.ItemState.BUSY)
		item.queue_free()
		emit_signal("inventory_changed")
		return true

	if item is KeyItem:
		if not keychain.has(item.key_id):
			keychain[item.key_id] = 0
		keychain[item.key_id] += 1

		# To make sure the item can't be interacted with again
		item.set_item_state(GlobalConsts.ItemState.BUSY)
		item.queue_free()
		return true

	return false


## Handles medical item consolidation into containers
## Returns true if item was consolidated into medical container, false otherwise
func handle_medical_consolidation(item: EquipmentItem) -> bool:
	assert(item != null, "Item should not be null in handle_medical_consolidation")

	# Before anything, check if this is a single-use medical item that can be consolidated into a container
	if item is MedicalItem and item.max_charges_held == 1:
		# Search for medical containers with space using search_hotbar utility

		# Data-returning seam (Brooks audit 1.1): GDScript lambdas capture locals
		# by value, so the old assign-in-lambda pattern never updated the outer
		# container_item/container_found locals. Matched pairs come back as data.
		var filter_func = func(potential_container):
			if potential_container == null:
				return false
			var is_medical = potential_container is MedicalItem
			var is_container = potential_container.max_charges_held > 1 if is_medical else false
			var has_space = potential_container.charges_held < potential_container.max_charges_held if is_container else false
			return is_medical and is_container and has_space

		var matched_pairs = search_hotbar_matched(filter_func)

		# Consolidate into the first matching container only
		if not matched_pairs.is_empty():
			var container_item: MedicalItem = matched_pairs[0][0]

			# Calculate how much space the container has
			var space_left = container_item.max_charges_held - container_item.charges_held

			# Add heal_amount to container (up to its capacity)
			var amount_to_add = min(space_left, item.heal_amount)
			container_item.charges_held += amount_to_add

			# Update the container's UI
			if container_item.has_signal("item_data_changed"):
				container_item.emit_signal("item_data_changed")

			# The incoming unit is spent as charges; free the node. An incoming
			# single-use medical never carries a stack of its own under the
			# record model (floor nodes carry no record), so there is no
			# stack branch here (T4).
			if item.is_inside_tree():
				var parent = item.get_parent()
				if parent != null:
					parent.remove_child(item)
			item.queue_free()

			emit_signal("inventory_changed")
			return true  # Item was consolidated, we're done

	return false


## Handles stackable item processing
## Returns true if item was stacked, false otherwise
func handle_stackable_items(item: EquipmentItem) -> bool:
	assert(item != null, "Item should not be null in handle_stackable_items")

	if item.stackable_resource == null:
		return false

	# Identity is the StackableResource res:// path, never the stack_name
	# nickname, which two different item types can share.
	var type_id := _stack_type_id_for_item(item)
	if type_id.is_empty():
		return false

	var stack_type := load(String(type_id)) as StackableResource
	if stack_type == null:
		return false

	# Only merge when some same-type record still has space under the type's
	# max_stack; otherwise place_in_hotbar starts a new stack.
	for record in records_for_type(type_id):
		if record.count >= stack_type.max_stack:
			continue  # Continue searching for other stacks with space

		# Absorb into the record first, only then free the node
		if not add_to_stack_record(type_id, item.scene_file_path, 1):
			return false
		# Schedule the item removal from the world
		if item.is_inside_tree():
			var parent = item.get_parent()
			if parent != null:
				parent.remove_child(item)
		# Properly dispose of the item to prevent it from being picked up again
		item.queue_free()

		emit_signal("inventory_changed")
		return true

	return false


## Handles hotbar placement logic
## Returns slot index where item was placed, or -1 if failed
func place_in_hotbar(item: EquipmentItem) -> int:
	assert(item != null, "Item should not be null in place_in_hotbar")
	assert(hotbar.size() == HOTBAR_SIZE, "Hotbar size mismatch")

	var slot: int = 0

	### Part 1 - Checks if something is in offhand; if not, and this is a light, put it in offhand
	if current_offhand_equipment == null or current_offhand_equipment is EmptyHand:
		if _item_is_light_source(item):
			if hotbar[slot] != null and !current_mainhand_slot:
				slot = current_offhand_slot
			if hotbar[slot] != null:
				# Find the lowest numbered empty slot (excluding slot 10 which is empty hands)
				slot = -1
				for i in range(10):  # Slots 0-9 only
					if hotbar[i] == null:
						slot = i
						break
			if slot == current_mainhand_slot:
				slot += 1
			# Audit Finding 1.2: the bumped slot may already be occupied; fall
			# through to the next free slot instead of overwriting its occupant
			if slot != -1 and hotbar[slot] != null:
				var bumped_slot: int = slot
				# Find the lowest numbered empty slot after the bumped slot
				# (excluding slot 10 which is empty hands)
				slot = -1
				for i in range(bumped_slot, 10):  # Slots up to 9 only
					if hotbar[i] == null:
						slot = i
						break
			# Safety check: if no empty slots found, don't place the light
			if slot != 10 and slot != -1 and slot < hotbar.size():
				hotbar[slot] = item
				# If the item is stackable, it becomes the representative of
				# its own new record (T2)
				if item.stackable_resource != null:
					_tag_new_stack_record(item)
				# Schedule the item removal from the world
				if item.is_inside_tree():
					var parent = item.get_parent()
					if parent != null:
						parent.remove_child(item)

				emit_signal("hotbar_changed", slot)
				emit_signal("inventory_changed")

				if not bulky_equipment:
					set_offhand_slot(slot)   # This is what puts it in off-hand
					equip_offhand_item()
					return slot   # Thus not processing the further autoequip logic below

	### Part 2 - Otherwise, normal rules: Select the lowest numbered available slot
	slot = current_mainhand_slot

	# If current mainhand slot is occupied, find the lowest numbered empty slot
	if hotbar[slot] != null:
		# Find the lowest numbered empty slot (excluding slot 10 which is empty hands)
		slot = -1
		for i in range(10):  # Slots 0-9 only
			if hotbar[i] == null:
				slot = i
				break

		# If no empty slots found, this will be handled below
		if slot == -1:
			push_error("No empty slots found, pickup will fail")

	# This checks if the slot to add the item isn't the hands-free slot and is valid, then adds the item to the slot
	if slot != 10 and slot != -1 and slot < hotbar.size():
		hotbar[slot] = item

		# If the item is stackable, it becomes the representative of its own
		# new record (T3)
		if item.stackable_resource != null:
			_tag_new_stack_record(item)
		# Schedule the item removal from the world
		if item.is_inside_tree():
			var parent = item.get_parent()
			if parent != null:
				parent.remove_child(item)

		emit_signal("hotbar_changed", slot)
		emit_signal("inventory_changed")
		return slot
	elif slot == -1:
		# No empty slots available, hotbar is full
		push_error("Hotbar is full, cannot add item: ", item.name)
		return -1

	return slot


## Handles auto-equipping logic
## Returns true if item was auto-equipped, false otherwise
func auto_equip_item(item: EquipmentItem, slot: int) -> bool:
	assert(item != null, "Item should not be null in auto_equip_item")
	assert(slot >= 0 and slot < HOTBAR_SIZE, "Invalid slot index in auto_equip_item")

	### Auto-equip
	# Autoequip if possible - main idea is prefer lights in off-hand and never forceably
	# put a medium gun in hand if it means pushing out a (lit) light-source
	# (we currently don't check if it's lit)
	if current_mainhand_slot == slot and not bulky_equipment:
		if _item_is_light_source(current_offhand_equipment):
			if item.item_size == GlobalConsts.ItemSize.SIZE_SMALL:
				equip_mainhand_item()
				return true
			if item.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM and item is MeleeItem:
				equip_mainhand_item()
				return true

		elif item.item_size == GlobalConsts.ItemSize.SIZE_SMALL:
			equip_mainhand_item()
			return true

		# Medium items
		elif item.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM:
			equip_mainhand_item()
			return true

	elif current_offhand_slot == slot and not bulky_equipment and item.item_size == GlobalConsts.ItemSize.SIZE_SMALL:
		equip_offhand_item()
		return true

	return false


# Attempts to add a node as an Item to this inventory, returns 'true'
# if the attempt was successful, or 'false' otherwise
func add_item(item : PickableItem) -> bool:
	# Validate item pickup
	if not can_pickup_item(item):
		return false

	assert(item != null, "Item should not be null after validation")
	assert(character != null, "Character should not be null")

	item.owner_character = character

	# Handle tiny items (TinyItem and KeyItem)
	if handle_tiny_items(item):
		return true

	elif item is EquipmentItem:
		# Update the inventory info immediately
		# This is a bulky item, or there is no space on the hotbar
		if item.item_size == GlobalConsts.ItemSize.SIZE_BULKY or !hotbar.has(null):
			drop_bulky_item()
			unequip_mainhand_item()
			unequip_offhand_item()
			equip_bulky_item(item)
			return true
		else:
			if handle_medical_consolidation(item):
				return true

			if handle_stackable_items(item):
				return true

			var slot: int = place_in_hotbar(item)
			if slot == -1:
				return false

			# Auto-equip if appropriate
			auto_equip_item(item, slot)

			# Encumbrance makes character louder and more visible. Character uses more stamina.
			# Eventually will affect mantling and swimming.
			_recount_encumbrance()   # SEAM ADD

			return true

	# If we reach here, the item type wasn't handled
	push_error("Item type not handled in add_item: ", item.name)
	return false


# Functions to interact with tiny items

## Insert a tiny_item into the inventory, it also neeeds an amount, emits tiny_item_changed
func insert_tiny_item(item : TinyItemData, amount : int):
	assert(item != null, "TinyItemData should not be null")
	assert(amount > 0, "Amount should be positive")

	if not tiny_items.has(item):
		tiny_items[item] = 0
	known_tiny_items[item] = true
	var prev = tiny_items[item]
	tiny_items[item] += amount
	var new = tiny_items[item]
	emit_signal("tiny_item_changed", item, prev, new)

## Remove a tiny_item from the inventory, it also neeeds an amount, emits tiny_item_changed
func remove_tiny_item(item : TinyItemData, amount : int) -> bool:
	if item == null:
		push_error("Cannot remove null TinyItemData")
		return false

	assert(amount > 0, "Amount should be positive")

	if tiny_items.has(item) and tiny_items[item] >= amount:
		var prev = tiny_items[item]
		tiny_items[item] -= amount
		var new = tiny_items[item]
		if tiny_items[item] == 0:
			tiny_items.erase(item)
		emit_signal("tiny_item_changed", item, prev, new)
		return true
	return false

## Retrieves the amount of a tiny item in the invetory, if the item is not present, returns 0
func tiny_item_amount(item : TinyItemData) -> int:
	if item == null:
		push_error("Cannot get amount for null TinyItemData")
		return 0
	return 0 if not tiny_items.has(item) else tiny_items[item]


# Stack record API. Records are the count model for stacks (StackableStackRecord);
# item scripts call this API and never touch record internals.


## Adds units of one stackable type to the stack records. Merges into the first
## record of that type with space under the type's max_stack, creating a new
## record when none fits. per_item_state seeds a new record; when merging, its
## keys are added without overwriting the record's existing entries.
## Returns true when the inventory owns the units afterwards.
func add_to_stack_record(type_id : StringName, item_scene_path : String, amount : int, per_item_state : Dictionary = {}) -> bool:
	if amount <= 0:
		push_warning("add_to_stack_record: amount must be positive, got ", amount)
		return false
	if not ResourceLoader.exists(String(type_id)):
		push_warning("add_to_stack_record: no StackableResource at ", type_id)
		return false
	var stack_type := load(String(type_id)) as StackableResource
	if stack_type == null:
		push_warning("add_to_stack_record: not a StackableResource at ", type_id)
		return false
	if not ResourceLoader.exists(item_scene_path):
		push_warning("add_to_stack_record: no item scene at ", item_scene_path)
		return false

	_destroy_empty_records()

	var target : StackableStackRecord = null
	for record in stack_records:
		if record.type_id == type_id and record.count + amount <= stack_type.max_stack:
			target = record
			break

	if target == null:
		target = StackableStackRecord.new()
		target.id = _next_stack_record_id
		_next_stack_record_id += 1
		target.type_id = type_id
		target.item_scene_path = item_scene_path
		target.count = 0
		target.per_item_state = per_item_state.duplicate()
		stack_records.append(target)
	else:
		target.per_item_state.merge(per_item_state)

	target.count += amount
	_recount_encumbrance()   # SEAM ADD
	return true


## Removes units from the record with the given id. Fails without mutation
## when the record does not exist or holds fewer units than requested.
## Returns true when the units were removed.
func remove_from_stack_record(record_id : int, amount : int) -> bool:
	if amount <= 0:
		push_warning("remove_from_stack_record: amount must be positive, got ", amount)
		return false
	var record := get_stack_record(record_id)
	if record == null:
		push_warning("remove_from_stack_record: no record with id ", record_id)
		return false
	if record.count < amount:
		push_warning("remove_from_stack_record: record ", record_id, " holds ", record.count, " of the requested ", amount)
		return false

	record.count -= amount
	_recount_encumbrance()   # SEAM REMOVE
	_destroy_empty_records()
	return true


## Spawns a world node for one unit of the record and decrements the record.
## The spawned node is unparented and carries this record's id. Returns null
## and keeps the record untouched when the record is unknown or empty, or the
## item scene fails to instantiate: the spawn happens before the decrement, so
## a failed materialization never loses an owned unit.
func materialize_stack_item(record_id : int) -> EquipmentItem:
	var record := get_stack_record(record_id)
	if record == null:
		push_warning("materialize_stack_item: no record with id ", record_id)
		return null
	if record.count <= 0:
		push_warning("materialize_stack_item: record ", record_id, " is empty")
		return null
	var scene : PackedScene = load(record.item_scene_path)
	if scene == null:
		push_error("materialize_stack_item: no scene at ", record.item_scene_path)
		return null
	var item := scene.instantiate() as EquipmentItem
	if item == null:
		push_error("materialize_stack_item: scene root is not an EquipmentItem: ", record.item_scene_path)
		return null

	record.count -= 1
	item.stack_record_id = record.id
	_recount_encumbrance()   # SEAM REMOVE
	_destroy_empty_records()
	return item


## Returns the record with the given id, or null when the inventory holds none.
func get_stack_record(record_id : int) -> StackableStackRecord:
	for record in stack_records:
		if record.id == record_id:
			return record
	return null


## Returns every record of one stackable type, in creation order. Same-type
## records are allowed: one record per hotbar slot's stack.
func records_for_type(type_id : StringName) -> Array[StackableStackRecord]:
	var matched : Array[StackableStackRecord] = []
	for record in stack_records:
		if record.type_id == type_id:
			matched.append(record)
	return matched


## Returns the stack type id (the StackableResource res:// path) for an item.
## A scene instance's resource is a local_to_scene duplicate whose
## resource_path is empty, so the authored path is recovered from the item
## scene's stored state and cached per scene path.
func _stack_type_id_for_item(item: EquipmentItem) -> StringName:
	if item.stackable_resource == null:
		return &""
	if not item.stackable_resource.resource_path.is_empty():
		return StringName(item.stackable_resource.resource_path)
	if item.scene_file_path.is_empty():
		return &""
	if _stack_type_id_cache.has(item.scene_file_path):
		return _stack_type_id_cache[item.scene_file_path]
	var type_id := &""
	var scene: PackedScene = load(item.scene_file_path)
	if scene != null:
		var state := scene.get_state()
		for node_idx in range(state.get_node_count()):
			for prop_idx in range(state.get_node_property_count(node_idx)):
				if state.get_node_property_name(node_idx, prop_idx) == "stackable_resource":
					var value: Variant = state.get_node_property_value(node_idx, prop_idx)
					if value is Resource and not value.resource_path.is_empty():
						type_id = StringName(value.resource_path)
						break
			if not type_id.is_empty():
				break
	_stack_type_id_cache[item.scene_file_path] = type_id
	return type_id


## Creates the first record for a newly placed stackable node and tags the
## node as its representative (T2/T3). place_in_hotbar only runs after
## handle_stackable_items found no record with space, so the record API
## always creates a fresh record here: the newest of the type's records.
func _tag_new_stack_record(item: EquipmentItem) -> void:
	var type_id := _stack_type_id_for_item(item)
	if type_id.is_empty():
		push_warning("place_in_hotbar: stackable has no StackableResource path, no record created")
		return
	if not add_to_stack_record(type_id, item.scene_file_path, 1):
		push_warning("place_in_hotbar: stack record creation failed for ", item.scene_file_path)
		return
	var records := records_for_type(type_id)
	if not records.is_empty():
		item.stack_record_id = records[records.size() - 1].id


## Destroys every record that reached count 0 with no hotbar slot or hand
## still holding its representative node.
func _destroy_empty_records() -> void:
	for record in stack_records.duplicate():
		if record.count > 0:
			continue
		if _record_has_representative(record.id):
			continue
		stack_records.erase(record)


## Returns whether a hotbar slot or hand still holds a node tagged with the
## given record id.
func _record_has_representative(record_id : int) -> bool:
	for entry in hotbar:
		var item := entry as EquipmentItem
		if item != null and is_instance_valid(item) and item.stack_record_id == record_id:
			return true
	if current_mainhand_equipment != null and is_instance_valid(current_mainhand_equipment) \
			and current_mainhand_equipment.stack_record_id == record_id:
		return true
	if current_offhand_equipment != null and is_instance_valid(current_offhand_equipment) \
			and current_offhand_equipment.stack_record_id == record_id:
		return true
	return false


## SEAM ADD and SEAM REMOVE: the only writers of encumbrance. Every owned
## count mutation calls this full recount over the inventory content instead
## of incremental adjustments, so drift self-heals at the next mutation.
func _recount_encumbrance() -> void:
	var total := 0.0
	for entry in hotbar:
		total += _encumbrance_for_item(entry as EquipmentItem)
	total += _encumbrance_for_item(bulky_equipment)
	encumbrance = total


## Encumbrance contribution of one owned item: its size weight times the units
## it stands for. A record-backed representative counts its record's units
## (the representative itself is one of them, counted once per record); a
## stackable without a record counts its legacy items_stacked members; anything
## else is one unit. A record with no representative in the hotbar or hands
## contributes nothing yet; the pickup flows place the representative in the
## same frame that creates its record. Tiny items are tracked by amount only
## and weigh nothing.
func _encumbrance_for_item(item : EquipmentItem) -> float:
	if item == null or not is_instance_valid(item):
		return 0.0
	var weight := _encumbrance_weight_for_size(item.item_size)
	if weight == 0:
		return 0.0

	var units := 1
	if item.stack_record_id >= 0:
		var record := get_stack_record(item.stack_record_id)
		if record != null:
			units = record.count
			# One representative reports the whole record; additional tagged
			# nodes for the same record (a swap's transient state) add nothing.
			return weight * units
	if item.stackable_resource != null:
		units = item.stackable_resource.items_stacked.size()
		if units < 1:
			units = 1
	return weight * units


## Per-unit weight by item size: the single weight table (SIZE_SMALL = 0,
## SIZE_MEDIUM = 1, SIZE_BULKY = 2; any other size weighs 0).
func _encumbrance_weight_for_size(size : GlobalConsts.ItemSize) -> int:
	match size:
		GlobalConsts.ItemSize.SIZE_MEDIUM:
			return 1
		GlobalConsts.ItemSize.SIZE_BULKY:
			return 2
		_:
			return 0


## Perfoms heavy logic to equip the mainhand_item, it uses the var current_mainhand_equipment
func equip_mainhand_item():
	await get_tree().create_timer(0.5).timeout
	# temporary hack (issue #409)
	if not is_instance_valid(current_mainhand_equipment):
		current_mainhand_equipment = null

	if current_mainhand_equipment != null: # Item already equipped
		return

	assert(current_mainhand_slot >= 0 and current_mainhand_slot < hotbar.size(), "Invalid mainhand slot")
	assert(character != null, "Character should not be null")
	assert(character.main_hand_root != null, "Main hand root should not be null")

	var item : EquipmentItem = hotbar[current_mainhand_slot] as EquipmentItem
	if item and is_instance_valid(item):
		# Can't equip a Bulky Item simultaneously with a normal item
		drop_bulky_item()
		# Can't equip item in both hands
		if current_offhand_equipment == item:
			unequip_offhand_item()

		item.set_item_state(GlobalConsts.ItemState.EQUIPPED)
		current_mainhand_equipment = item

		item.transform = item.get_hold_transform()
		if item.is_in_belt == true:
			remove_from_belt(item)
			var parent = item.get_parent()
			if parent != null:
				parent.remove_child(item)
			character.main_hand_root.add_child(item)
		else:
			character.main_hand_root.add_child(item)
		emit_signal("inventory_changed")
	else:
		pass

## Perfoms heavy logic to unequip the mainhand_item, it uses the var current_mainhand_equipment
func unequip_mainhand_item():
	# temporary hack (issue #409)
	if not is_instance_valid(current_mainhand_equipment):
		current_mainhand_equipment = null

	if current_mainhand_equipment == null:   # No item equipped
		return

	emit_signal("unequip_mainhand")
	var item = current_mainhand_equipment
	current_mainhand_equipment = null
	if item != null:
		if item.can_attach == true:
			pass
		else:
			var parent = item.get_parent()
			if parent != null:
				parent.remove_child(item)

## Perfoms heavy logic to equip a bulky_item and clearing the player hands for it
func equip_bulky_item(item : EquipmentItem):
	assert(character != null, "Character should not be null")
	assert(character.main_hand_root != null, "Main hand root should not be null")

	# Clear any currently equipped items
	unequip_mainhand_item()
	unequip_offhand_item()
	drop_bulky_item()
	if item != null:
		item.set_item_state(GlobalConsts.ItemState.EQUIPPED)
		item.transform = item.get_hold_transform()
		bulky_equipment = item
		emit_signal("bulky_item_changed")
		var parent = item.get_parent()
		if parent != null:
			parent.remove_child(item)
		character.main_hand_root.add_child(item)
		emit_signal("inventory_changed")


func drop_bulky_item():
	if bulky_equipment == null:
		return
	# If the item was just equipped, waits for it to enter the tree before removing
	var item = bulky_equipment
	bulky_equipment = null
	emit_signal("bulky_item_changed")
	if item != null:
		var parent = item.get_parent()
		if parent != null:
			parent.remove_child(item)
		_drop_item(item)


func equip_offhand_item():
	assert(character != null, "Character should not be null")
	assert(character.off_hand_root != null, "Off hand root should not be null")
	assert(current_offhand_slot >= 0 and current_offhand_slot < hotbar.size(), "Invalid offhand slot")

	var equip_delay = 0.5
	if current_offhand_equipment is MeleeItem:
		equip_delay = 0.1
	else:
		equip_delay = 0.5

	await get_tree().create_timer(equip_delay).timeout
	# Item already equipped or both slots set to the same item
	if current_offhand_equipment != null or current_offhand_slot == current_mainhand_slot:
		return
	var item : EquipmentItem = hotbar[current_offhand_slot]
	if not is_instance_valid(item):
		return
	if not item.item_size == GlobalConsts.ItemSize.SIZE_SMALL:
		return
	if item == current_mainhand_equipment:
		return

	# Item exists, can be equipped on the offhand, and is not already equipped
	if current_mainhand_equipment and current_mainhand_equipment.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM and current_mainhand_equipment is GunItem:
		unequip_mainhand_item()

	# Can't equip a Bulky Item simultaneously with a normal item
	drop_bulky_item()
	
	# Safety check to prevent equipping freed instances
	if not is_instance_valid(item):
		return
		
	item.item_state = GlobalConsts.ItemState.EQUIPPED
	current_offhand_equipment = item
	# Waits for the item to exit the tree, if necessary
	item.transform = item.get_hold_transform()
	if item.is_in_belt == true:
		remove_from_belt(item)
		var parent = item.get_parent()
		if parent != null:
			parent.remove_child(item)
		character.off_hand_root.add_child(item)
	else:
		character.off_hand_root.add_child(item)


func unequip_offhand_item():
	if current_offhand_equipment == null: # No item equipped
		return

	# If the item was just equipped, waits for it to enter the tree before removing
	var item = current_offhand_equipment
	current_offhand_equipment = null
	emit_signal("unequip_offhand")
	if item != null:
		if item.can_attach == true:
			pass
		else:
			var parent = item.get_parent()
			if parent != null:
				parent.remove_child(item)


func drop_mainhand_item() -> Node:
	if bulky_equipment:
		var dropped = bulky_equipment
		drop_bulky_item()
		return dropped
	return drop_hotbar_slot(current_mainhand_slot)


func get_mainhand_item() -> EquipmentItem:
	# Check bulky equipment first
	if bulky_equipment != null:
		if not is_instance_valid(bulky_equipment):
			bulky_equipment = null
			return null
		return bulky_equipment
	
	# Check mainhand equipment
	if current_mainhand_equipment != null:
		if not is_instance_valid(current_mainhand_equipment):
			current_mainhand_equipment = null
			return null
		return current_mainhand_equipment
	
	return null


func get_offhand_item() -> EquipmentItem:
	if current_offhand_equipment != null:
		if not is_instance_valid(current_offhand_equipment):
			current_offhand_equipment = null
			return null
		return current_offhand_equipment
	return null


func has_bulky_item() -> bool:
	return bulky_equipment != null


func drop_offhand_item() -> Node:
	return drop_hotbar_slot(current_offhand_slot)


func drop_hotbar_slot(slot : int) -> Node:
	assert(slot >= 0 and slot < hotbar.size(), "Invalid slot index in drop_hotbar_slot")

	var item = hotbar[slot]
	var dropped_item : Node = null
	if item != null:
		var item_node = item as EquipmentItem
		if item_node == null:
			push_error("Item in hotbar slot is not an EquipmentItem")
			return item

		if item_node.stackable_resource == null:
			hotbar[slot] = null
			if current_mainhand_equipment == item_node:
				unequip_mainhand_item()
			elif current_offhand_equipment == item_node:
				unequip_offhand_item()
			if item_node != null:
				if item_node.can_attach == true:
					remove_from_belt(item)
					var parent = item_node.get_parent()
					if parent != null:
						parent.remove_child(item_node)
					_drop_item(item_node)
				else:
					_drop_item(item_node)
			dropped_item = item_node
		else:
			var hand = null
			if current_mainhand_equipment == item_node:
				unequip_mainhand_item()
				hand = HandEnum.MAIN_HAND
			elif current_offhand_equipment == item_node:
				unequip_offhand_item()
				hand = HandEnum.OFF_HAND

			# Record-aware drop (T8): the record is the count truth. With
			# units remaining, the representative stays in its slot and the
			# dropped unit is a fresh materialized node; the last unit drops
			# the representative itself, and the emptied record is destroyed
			# because the slot and hands were cleared before the remove.
			var record : StackableStackRecord = null
			if item_node.stack_record_id >= 0:
				record = get_stack_record(item_node.stack_record_id)

			if record != null and record.count > 1:
				dropped_item = materialize_stack_item(record.id)
				if dropped_item != null:
					_drop_item(dropped_item)
				else:
					# Spawn failed: the unit stays owned (no-destroy rule),
					# so nothing is dropped this time.
					push_warning("drop_hotbar_slot: materialization failed, the unit stays owned")
				# Re-equip the surviving representative
				match hand:
					HandEnum.MAIN_HAND:
						equip_mainhand_item()
					HandEnum.OFF_HAND:
						equip_offhand_item()
			else:
				hotbar[slot] = null
				if record != null:
					remove_from_stack_record(record.id, 1)
				if item_node.can_attach == true:
					remove_from_belt(item)
					var parent = item_node.get_parent()
					if parent != null:
						parent.remove_child(item_node)
					_drop_item(item_node)
				else:
					_drop_item(item_node)
				dropped_item = item_node
		emit_signal("hotbar_changed", slot)
	return dropped_item


# Drops the item, it must be unequipped first
# This positions the item at the 'PlaceOrigin' of the owner character,
# in a DROPPED state. Further positioning can be done by the caller
func _drop_item(item : EquipmentItem):
	item.set_item_state(GlobalConsts.ItemState.DROPPED)

	if is_instance_valid(GameManager.game.level):
		GameManager.game.level.add_child(item)
	else:
		find_parent("TestWorld").add_child(item)
	item.global_transform = character.place_origin.global_transform
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO

	item.owner_character = null

	_recount_encumbrance()   # SEAM REMOVE


# `slot_only` will simple change the slot variable, with no other changes
func set_mainhand_slot(value : int):
	if value != current_mainhand_slot:
		var previous_slot = current_mainhand_slot
		if hotbar[value] == get_mainhand_item():
			current_mainhand_slot = value
			mainhand_slot_changed.emit(previous_slot, value)
			inventory_changed.emit()
		else:
			unequip_mainhand_item()
			current_mainhand_slot = value
			equip_mainhand_item()
			mainhand_slot_changed.emit(previous_slot, value)
			inventory_changed.emit()
	else:
		if get_mainhand_item() == hotbar[current_mainhand_slot]:
			emit_signal("inventory_changed")
			unequip_mainhand_item()
		else:
			equip_mainhand_item()


func set_offhand_slot(value : int):
	if value != current_offhand_slot:
		var previous_slot = current_offhand_slot
		if hotbar[value] == get_offhand_item():
			current_offhand_slot = value
			offhand_slot_changed.emit(previous_slot, value)
			inventory_changed.emit()
		else:
			unequip_offhand_item()
			current_offhand_slot = value
			equip_offhand_item()
			offhand_slot_changed.emit(previous_slot, value)
			inventory_changed.emit()


# Equipment in each slot goes to other slot
func swap_slots(first_slot, second_slot):
	# store both items in temp
	var first_temp = hotbar[first_slot]
	var second_temp = hotbar[second_slot]
	# place first item in final slot
	hotbar[second_slot] = first_temp
	# place second item in initial slot
	hotbar[first_slot] = second_temp

	emit_signal("inventory_changed")
	emit_signal("hotbar_changed", first_slot)
	emit_signal("hotbar_changed", second_slot)

	if current_mainhand_slot == first_slot:
		current_mainhand_slot = second_slot
		mainhand_slot_changed.emit(first_slot, second_slot)
	elif current_mainhand_slot == second_slot:
		current_mainhand_slot = first_slot
		mainhand_slot_changed.emit(second_slot, first_slot)

	if current_offhand_slot == first_slot:
		current_offhand_slot = second_slot
		offhand_slot_changed.emit(first_slot, second_slot)
	elif current_offhand_slot == second_slot:
		current_offhand_slot = first_slot
		offhand_slot_changed.emit(second_slot, first_slot)


# Equipment in each hand goes to other hand
func swap_hands():
	# If bulky, don't do anything
	if bulky_equipment:
		return
	# If medium item in mainhand, can't do anything since medium items can't be in offhand
	if hotbar[current_mainhand_slot] and hotbar[current_mainhand_slot].item_size == GlobalConsts.ItemSize.SIZE_MEDIUM:
		return
	# There's probably a bug in here about light-sources staying lit, relating to unequipping items
	are_swapping = true
	var previous_mainhand = current_mainhand_slot
	var previous_offhand = current_offhand_slot

	# Avoids a bug if offhand is empty when swap where you can't pick anything up anymore after it
	if current_offhand_slot == 10:
		if current_mainhand_slot == 0:
			previous_offhand = 1
			set_mainhand_slot(previous_offhand)
		else:
			previous_offhand = 0
			set_mainhand_slot(previous_offhand)

		set_offhand_slot(previous_mainhand)
		unequip_mainhand_item()

	else:
		set_mainhand_slot(previous_offhand)
		set_offhand_slot(previous_mainhand)

	are_swapping = false


# Generalized hotbar searching utility function
# filter_func: Callable that takes an item and returns true if it matches the criteria
# action_func: Callable that takes an item and its index, performs an action on the item
# early_termination_func: Optional Callable that takes an item and returns true if search should stop
func search_hotbar(filter_func: Callable, action_func: Callable, early_termination_func: Callable = Callable()) -> bool:
	var items_processed = false
	for i in range(hotbar.size()):
		var item = hotbar[i]
		if item == null:
			continue

		# Apply filter condition
		if filter_func.call(item):
			# Perform action on matching item
			action_func.call(item, i)
			items_processed = true

			# Check for early termination
			if early_termination_func.is_valid() and early_termination_func.call(item):
				return true  # Early termination requested
	return items_processed  # Return true if any items were processed


# Data-returning hotbar search seam (Brooks audit 1.1): returns all matched
# (item, slot_index) pairs as two-entry arrays, in hotbar slot order. Callers
# act on the returned data instead of assigning to locals inside lambdas,
# which capture by value and never propagate.
func search_hotbar_matched(filter_func: Callable) -> Array:
	var matched_pairs : Array = []
	for i in range(hotbar.size()):
		var item = hotbar[i]
		if item == null:
			continue

		if filter_func.call(item):
			matched_pairs.append([item, i])
	return matched_pairs


## Clears the hotbar slot holding the given item and reports it to the UI
## (Brooks audit 4.5: an exploding bomb used to leave a freed reference in its
## hotbar slot). Returns true if a slot held the item.
func clear_hotbar_slot_of(item: EquipmentItem) -> bool:
	for i in range(hotbar.size()):
		if hotbar[i] == item:
			hotbar[i] = null
			emit_signal("hotbar_changed", i)
			return true
	return false


func switch_away_from_light(light_source):
	if not light_source.can_attach:
		if not are_swapping and character.player_controller.throw_state != character.player_controller.ThrowState.SHOULD_PLACE and character.player_controller.throw_state != character.player_controller.ThrowState.SHOULD_THROW:
			light_source.unlight()
	elif light_source.can_attach and light_source is LanternItem:
		attach_to_belt(light_source)


func attach_to_belt(item):
	if item.get_parent() != character.belt_position:
		item.mesh_instance.visible = false
		item.is_in_belt = true
		item.get_parent().remove_child(item)
		character.belt_position.add_child(item)
		belt_item = item


func remove_from_belt(item):
	item.mesh_instance.visible = true
	item.is_in_belt = false
	belt_item = null


func _on_Player_character_died():
	emit_signal("player_died")


func _item_is_light_source(item: PickableItem) -> bool:
	if item is CandleItem or item is TorchItem or item is CandelabraItem or item is LanternItem :
		return true
	else:
		return false
