extends Node
#class_name Inventory

signal bulky_item_changed()
# Emitted when a hotbar slot changes (item added or removed)
signal hotbar_changed(slot)
# Emitted when the user selects a new slot for the main hand
signal primary_slot_changed(previous, current)
# Emitted when the user selects a new slot for the offhand
signal secondary_slot_changed(previous, current)
# Emitted when the ammount of a tiny item changes
signal tiny_item_changed(item, previous_ammount, curent_ammount)
#Emitted to fadein the HUD UI
signal UpdateHud

const HOTBAR_SIZE : int= 10

# Items tracked exclusively by ammount, don't contribute to weight,
# don't show in hotbar
var tiny_items : Dictionary

# Dictionary of {int : int}, where the key is the key_id and the value is the amount of keys owned
# with that ID
var keychain : Dictionary

# Usable items that appear in the hotbar, as an array of nodes
var hotbar : Array

# A special kind of equipment, overrides the hotbar items, cannot be stored
var bulky_equipment : EquipmentItem = null

# Information about the item equipped on the main hand
var current_primary_slot : int = 0 setget set_primary_slot
var current_primary_equipment : EquipmentItem = null

# Information about the item equipped on the offhand
var current_secondary_slot : int = 0 setget set_secondary_slot
var current_secondary_equipment : EquipmentItem = null

# Where to drop items from
onready var drop_position_node : Spatial = $"%DropPosition" as Spatial

func _ready():
	hotbar.resize(HOTBAR_SIZE)

# Returns wether a given node can be added as an Item to this inventory
func can_pickup_item(item : PickableItem) -> bool:
	# Can only pickup dropped items
	# (may change later to steal weapons, or we can do that by dropping them first)
	# Also prevents picking up busy items
	if item.item_state != GlobalConsts.ItemState.DROPPED:
		return false
	# Can always pickup special items
	if (item is TinyItem) or (item is KeyItem):
		return true
	# Can always pick up equipment (goes to bulky slot if necessary)
	if item is EquipmentItem:
		return true
	return false

# Attempts to add a node as an Item to this inventory, returns 'true'
# if the attempt was successful, or 'false' otherwise
func add_item(item : PickableItem) -> bool:
	var can_pickup : bool = can_pickup_item(item)
	
	if not can_pickup:
		return false
	
	item.owner_character = owner
	
	if item is TinyItem:
		if item.item_data != null:
			insert_tiny_item(item.item_data, item.amount)
		# To make sure the item can't be interacted with again
		item.item_state = GlobalConsts.ItemState.BUSY
		item.queue_free()
	
	if item is KeyItem:
		if not keychain.has(item.key_id):
			keychain[item.key_id] = 0
		keychain[item.key_id] += 1
		# To make sure the item can't be interacted with again
		item.item_state = GlobalConsts.ItemState.BUSY
		item.queue_free()
	
	elif item is EquipmentItem:
		# Schedule the item removal from the world
		if item.is_inside_tree():
			item.get_parent().remove_child(item)
		# Update the inventory info immediately
		# This is a bulky item, or there is no space on the hotbar
		if item.item_size == GlobalConsts.ItemSize.SIZE_BULKY or !hotbar.has(null):
			drop_bulky_item()
			unequip_primary_item()
			unequip_secondary_item()
			equip_bulky_item(item)
		else:
			# Select an empty slot, prioritizing the current one, if empty
			var slot : int = current_primary_slot
			# Then the offhand
			if hotbar[slot] != null:
				slot = current_secondary_slot
				pass
			# Then the first empty slot
			if hotbar[slot] != null:
				slot = hotbar.find(null)
			# Add the item to the slot
			hotbar[slot] = item
			emit_signal("hotbar_changed", slot)
			emit_signal("UpdateHud")
			# Autoequip if possible
			if current_primary_slot == slot and not bulky_equipment:
				equip_primary_item()
			elif current_secondary_slot == slot and not bulky_equipment:
				equip_secondary_item()
	return true

# Functions to interact with tiny items
func insert_tiny_item(item : TinyItemData, amount : int):
	if not tiny_items.has(item):
		tiny_items[item] = 0
	var prev = tiny_items[item]
	tiny_items[item] += amount
	var new = tiny_items[item]
	emit_signal("tiny_item_changed", item, prev, new)

func remove_tiny_item(item : TinyItemData, amount : int) -> bool:
	if tiny_items.has(item) and tiny_items[item] >= amount:
		var prev = tiny_items[item]
		tiny_items[item] -= amount
		var new = tiny_items[item]
		if tiny_items[item] == 0:
			tiny_items.erase(item)
		emit_signal("tiny_item_changed", item, prev, new)
		return true
	return false

func tiny_item_amount(item : TinyItemData) -> int:
	return 0 if not tiny_items.has(item) else tiny_items[item]

func equip_primary_item():
	if current_primary_equipment != null: # Item already equipped
		return
	var item : EquipmentItem = hotbar[current_primary_slot] as EquipmentItem
	if item:
		# Can't Equip a Bulky Item simultaneously with a normal item
		drop_bulky_item()
		# Can't Equip item on both hands
		if current_secondary_equipment == item:
			unequip_secondary_item()
		item.item_state = GlobalConsts.ItemState.EQUIPPED
		current_primary_equipment = item
		item.transform = item.get_hold_transform()
		owner.primary_equipment_root.add_child(item)
		emit_signal("UpdateHud")
func unequip_primary_item():
	if current_primary_equipment == null: # No item equipped
		return
	current_primary_equipment.item_state = GlobalConsts.ItemState.INVENTORY
	var item = current_primary_equipment
	current_primary_equipment = null
	item.get_parent().remove_child(item)

func equip_bulky_item(item : EquipmentItem):
	# Clear any currently equipped items
	unequip_primary_item()
	unequip_secondary_item()
	drop_bulky_item()
	if item:
		item.item_state = GlobalConsts.ItemState.EQUIPPED
		item.transform = item.get_hold_transform()
		bulky_equipment = item
		emit_signal("bulky_item_changed")
		owner.primary_equipment_root.add_child(item)
		emit_signal("UpdateHud")
	pass

func drop_bulky_item():
	if bulky_equipment == null:
		return
	# If the item was just equipped, waits for it to enter the tree before removing
	var item = bulky_equipment
	bulky_equipment = null
	emit_signal("bulky_item_changed")
	item.get_parent().remove_child(item)
	_drop_item(item)
	pass

func equip_secondary_item():
	# Item already equipped or both slots set to the same item
	if current_secondary_equipment != null or current_secondary_slot == current_primary_slot:
		return
	var item : EquipmentItem = hotbar[current_secondary_slot]
	# Item exists, can be equipped on the offhand, and is not already equipped
	if item and item.item_size == GlobalConsts.ItemSize.SIZE_SMALL and not item == current_primary_equipment:
		# Can't Equip a Bulky Item simultaneously with a normal item
		drop_bulky_item()
		item.item_state = GlobalConsts.ItemState.EQUIPPED
		current_secondary_equipment = item
		# Waits for the item to exit the tree, if necessary
		item.transform = item.get_hold_transform()
		owner.secondary_equipment_root.add_child(item)
	pass

func unequip_secondary_item():
	if current_secondary_equipment == null: # No item equipped
		return
	current_secondary_equipment.item_state = GlobalConsts.ItemState.INVENTORY
	# If the item was just equipped, waits for it to enter the tree before removing
	var item = current_secondary_equipment
	current_secondary_equipment = null
	item.get_parent().remove_child(item)
	pass

func drop_primary_item():
	if bulky_equipment:
		drop_bulky_item()
	else:
		drop_hotbar_slot(current_primary_slot)
	pass

func get_primary_item() -> EquipmentItem:
	return bulky_equipment if bulky_equipment else current_primary_equipment

func get_secondary_item() -> EquipmentItem:
	return current_secondary_equipment

func has_bulky_item() -> bool:
	return bulky_equipment != null

func drop_secondary_item():
	drop_hotbar_slot(current_secondary_slot)
	pass

func drop_hotbar_slot(slot : int) -> Node:
	var item = hotbar[slot]
	if not item == null:
		var item_node = item as EquipmentItem
		hotbar[slot] = null
		if current_primary_equipment == item_node:
			unequip_primary_item()
		elif current_secondary_equipment == item_node:
			unequip_secondary_item()
		if item_node:
			_drop_item(item_node)
		emit_signal("hotbar_changed", slot)
	return item

# Drops the item, it must be unequipped first
# note that the drop is done in a deferred manner
func _drop_item(item : EquipmentItem):
	item.item_state = GlobalConsts.ItemState.DROPPED
	if GameManager.game.level:
		item.global_transform = drop_position_node.global_transform
		GameManager.game.level.add_child(item)
	pass

func set_primary_slot(value : int):
	if value != current_primary_slot:
		unequip_primary_item()
		var previous_slot = current_primary_slot
		current_primary_slot = value
		equip_primary_item()
		emit_signal("primary_slot_changed", previous_slot, value)
		emit_signal("UpdateHud")
	else:
		if get_primary_item() == hotbar[current_primary_slot]:
			unequip_primary_item()
		else:
			equip_primary_item()

func set_secondary_slot(value : int):
	if value != current_secondary_slot:
		var previous_slot = current_secondary_slot
		unequip_secondary_item()
		current_secondary_slot = value
		equip_secondary_item()
		emit_signal("secondary_slot_changed", previous_slot, value)
