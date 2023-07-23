#class_name Inventory
extends Node


signal bulky_item_changed()
# Emitted when a hotbar slot changes (item added or removed)
signal hotbar_changed(slot)
# Emitted when the user selects a new slot for the main hand
signal mainhand_slot_changed(previous, current)
# Emitted when the user selects a new slot for the offhand
signal offhand_slot_changed(previous, current)
# Emitted when the ammount of a tiny item changes

signal tiny_item_changed(item, previous_ammount, curent_ammount)
#Emitted to fadein the HUD UI
signal inventory_changed
#Emitted to hide the HUD UI when player dies
signal player_died

signal unequip_mainhand
signal unequip_offhand
# 0 is 1, 10 is empty_hands
const HOTBAR_SIZE : int = 11

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
var current_mainhand_slot : int = 0 setget set_mainhand_slot
var current_mainhand_equipment : EquipmentItem = null

# Information about the item equipped on the offhand
var current_offhand_slot : int = 0 setget set_offhand_slot
var current_offhand_equipment : EquipmentItem = null

# Where to drop items from
onready var drop_position_node : Spatial = $"../Body/DropPosition" as Spatial
onready var Animations : AnimationPlayer = $"%AdditionalAnimations" as AnimationPlayer

var encumbrance : float = 0   # Is a float to allow easy division


func _ready():
	hotbar.resize(HOTBAR_SIZE)
	current_offhand_slot = 10

func _process(delta):
	pass
#	print(hotbar[current_mainhand_slot])

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
		emit_signal("inventory_changed")
	
	
	if item is KeyItem:
		if not keychain.has(item.key_id):
			keychain[item.key_id] = 0
		keychain[item.key_id] += 1
		# To make sure the item can't be interacted with again
		item.item_state = GlobalConsts.ItemState.BUSY
		item.queue_free()
	
	elif item is EquipmentItem:
	
		# Update the inventory info immediately
		# This is a bulky item, or there is no space on the hotbar
		if item.item_size == GlobalConsts.ItemSize.SIZE_BULKY or !hotbar.has(null):
			drop_bulky_item()
			unequip_mainhand_item()
			unequip_offhand_item()
			equip_bulky_item(item)
		else:
			var slot = 0
			
			### Probably can be cleaned up - part 1 is to put lights offhand, part 2 is everything else
			# Checks if something is in offhand; if not, and this is a light, put it there
			if current_offhand_equipment == null or current_offhand_equipment == EmptyHand:
				print("Offhand null or empty hands")
				if item is CandleItem or item is TorchItem or item is CandelabraItem or item is LanternItem:
					print("...and is a light")
					if hotbar[slot] != null and !current_mainhand_slot:
						print ("...slot isn't empty and it's not the mainhand one")
						slot = current_offhand_slot
					if hotbar[slot] != null:
						slot = hotbar.find(null)
					if slot == current_mainhand_slot:
						slot += 1
					if slot != 10:
						hotbar[slot] = item
						print("Light-source going to slot ", slot)
						# Schedule the item removal from the world
						if item.is_inside_tree():
							item.get_parent().remove_child(item)
						
						emit_signal("hotbar_changed", slot)
						emit_signal("inventory_changed")
						
						if not bulky_equipment:
							set_offhand_slot(slot)   # This is what puts it in off-hand
							equip_offhand_item()
							return true
					
			### Otherwise, normal rules: Select an empty slot, prioritizing the current one, if empty
			slot = current_mainhand_slot
			# Then the offhand, preferring this slot for lights
			if hotbar[slot] != null:
				slot = current_offhand_slot
			# Then the first empty slot
			if hotbar[slot] != null:
				slot = hotbar.find(null)
			# This checks if the slot to add the item isn't the item free slot then adds the item to the slot
			if slot != 10:
				hotbar[slot] = item
				# Schedule the item removal from the world
				if item.is_inside_tree():
					item.get_parent().remove_child(item)
				
				emit_signal("hotbar_changed", slot)
				emit_signal("inventory_changed")
				
				# Autoequip if possible
				# Everything else including another light-source, just put it in the main-hand
				if current_mainhand_slot == slot and not bulky_equipment:
					if check_offhand_equipped(item):
						equip_mainhand_item()
				
				elif current_offhand_slot == slot and not bulky_equipment:
					equip_offhand_item()
					
			if item.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM:
				encumbrance += 1
			if item.item_size == GlobalConsts.ItemSize.SIZE_BULKY:
				encumbrance += 2
			
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


func check_offhand_equipped(item):
	var can_equip
	if item.item_size != GlobalConsts.ItemSize.SIZE_MEDIUM and item != GunItem and current_offhand_equipment != LanternItem and current_offhand_equipment != CandleItem and current_offhand_equipment != TorchItem and current_offhand_equipment != CandelabraItem:
		can_equip = true
	else:
		can_equip = false
		
	return can_equip


func tiny_item_amount(item : TinyItemData) -> int:
	return 0 if not tiny_items.has(item) else tiny_items[item]


func equip_mainhand_item():
	# temporary hack (issue #409)
	if not is_instance_valid(current_mainhand_equipment):
		current_mainhand_equipment = null
	
	if current_mainhand_equipment != null: # Item already equipped
		return
		
	var item : EquipmentItem = hotbar[current_mainhand_slot] as EquipmentItem
	if item:
		# Can't equip a Bulky Item simultaneously with a normal item
		drop_bulky_item()
		# Can't equip item in both hands
		if current_offhand_equipment == item:
			unequip_offhand_item()
		
			
		item.item_state = GlobalConsts.ItemState.EQUIPPED
		current_mainhand_equipment = item
		item.transform = item.get_hold_transform()
		if item.is_in_belt == true:
			item.get_parent().remove_child(item)
			owner.mainhand_equipment_root.add_child(item)
		else:
			owner.mainhand_equipment_root.add_child(item)
		emit_signal("inventory_changed")


func unequip_mainhand_item():
	# temporary hack (issue #409)
	if not is_instance_valid(current_mainhand_equipment):
		current_mainhand_equipment = null
	
	if current_mainhand_equipment == null:   # No item equipped
		return
	
	current_mainhand_equipment.item_state = GlobalConsts.ItemState.INVENTORY
	emit_signal("unequip_mainhand")
	var item = current_mainhand_equipment
	current_mainhand_equipment = null
	if item.can_attach == true:
		pass
	else:
		item.get_parent().remove_child(item)


func equip_bulky_item(item : EquipmentItem):
	# Clear any currently equipped items
	unequip_mainhand_item()
	unequip_offhand_item()
	drop_bulky_item()
	if item:
		item.item_state = GlobalConsts.ItemState.EQUIPPED
		item.transform = item.get_hold_transform()
		bulky_equipment = item
		emit_signal("bulky_item_changed")
		if item.get_parent():
			item.get_parent().remove_child(item)
		owner.mainhand_equipment_root.add_child(item)
		emit_signal("inventory_changed")


func drop_bulky_item():
	if bulky_equipment == null:
		return
	# If the item was just equipped, waits for it to enter the tree before removing
	var item = bulky_equipment
	bulky_equipment = null
	emit_signal("bulky_item_changed")
	item.get_parent().remove_child(item)
	_drop_item(item)


func equip_offhand_item():
	# Item already equipped or both slots set to the same item
	if current_offhand_equipment != null or current_offhand_slot == current_mainhand_slot:
		return
	var item : EquipmentItem = hotbar[current_offhand_slot]
	# Item exists, can be equipped on the offhand, and is not already equipped
	if current_mainhand_equipment and current_mainhand_equipment.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM and current_mainhand_equipment is GunItem:
		
		if item is CandleItem or item is TorchItem or item is CandelabraItem or item is LanternItem:
			print("Equipped offhand light item")
		else:
			print("Equipped offhand slot normal item")
			current_offhand_slot = 10
			unequip_offhand_item()
		
	elif item and item.item_size == GlobalConsts.ItemSize.SIZE_SMALL and not item == current_mainhand_equipment:
		# Can't equip a Bulky Item simultaneously with a normal item
		drop_bulky_item()
		item.item_state = GlobalConsts.ItemState.EQUIPPED
		current_offhand_equipment = item
		# Waits for the item to exit the tree, if necessary
		item.transform = item.get_hold_transform()
		if item.is_in_belt == true:
			item.get_parent().remove_child(item)
			owner.offhand_equipment_root.add_child(item)
		else:
			owner.offhand_equipment_root.add_child(item)


func unequip_offhand_item():
	if current_offhand_equipment == null: # No item equipped
		return
	current_offhand_equipment.item_state = GlobalConsts.ItemState.INVENTORY
	# If the item was just equipped, waits for it to enter the tree before removing
	var item = current_offhand_equipment
	current_offhand_equipment = null
	emit_signal("unequip_offhand")
	if item.can_attach == true:
		pass
	else:
		set_offhand_slot(10)
		item.get_parent().remove_child(item)


func drop_mainhand_item():
	if bulky_equipment:
		drop_bulky_item()
	else:
		drop_hotbar_slot(current_mainhand_slot)
	pass


func get_mainhand_item() -> EquipmentItem:
	return bulky_equipment if bulky_equipment else current_mainhand_equipment


func get_offhand_item() -> EquipmentItem:
	return current_offhand_equipment


func has_bulky_item() -> bool:
	return bulky_equipment != null


func drop_offhand_item():
	drop_hotbar_slot(current_offhand_slot)


func drop_hotbar_slot(slot : int) -> Node:
	var item = hotbar[slot]
	if not item == null:
		var item_node = item as EquipmentItem
		hotbar[slot] = null
		if current_mainhand_equipment == item_node:
			unequip_mainhand_item()
		elif current_offhand_equipment == item_node:
			unequip_offhand_item()
		if item_node:
			if item_node.can_attach == true:
				item_node.get_parent().remove_child(item_node)
				item_node.is_in_belt = false
				_drop_item(item_node)
			else:
				_drop_item(item_node)
		emit_signal("hotbar_changed", slot)
	return item


# Drops the item, it must be unequipped first
# Note that the drop is done in a deferred manner
func _drop_item(item : EquipmentItem):
	item.item_state = GlobalConsts.ItemState.DROPPED
	if !GameManager.game:   # This is here for test scenes
		item.global_transform = drop_position_node.global_transform
		find_parent("TestWorld").add_child(item)
		return
	if GameManager.game.level:   # This is for the real game
		item.global_transform = drop_position_node.global_transform
		if item.can_attach == true:
#			item.get_parent().remove_child(item)
			GameManager.game.level.add_child(item)
		else:
			GameManager.game.level.add_child(item)

	if item.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM:
		encumbrance -= 1
	if item.item_size == GlobalConsts.ItemSize.SIZE_BULKY:
		encumbrance -= 2


func set_mainhand_slot(value : int):
	if value != current_mainhand_slot:
		unequip_mainhand_item()
		var previous_slot = current_mainhand_slot
		current_mainhand_slot = value
		equip_mainhand_item()
		emit_signal("mainhand_slot_changed", previous_slot, value)
		emit_signal("inventory_changed")
	else:
		if get_mainhand_item() == hotbar[current_mainhand_slot]:
			emit_signal("inventory_changed")
			unequip_mainhand_item()
		else:
			equip_mainhand_item()


func set_offhand_slot(value : int):
	if value != current_offhand_slot:
		var previous_slot = current_offhand_slot
		unequip_offhand_item()
		current_offhand_slot = value
		equip_offhand_item()
		emit_signal("offhand_slot_changed", previous_slot, value)
		emit_signal("inventory_changed")


func attach_to_belt(item):
	if item.get_parent() != owner.belt_position:
		item.get_parent().remove_child(item)
		owner.belt_position.add_child(item)
		$"%AdditionalAnimations".play("Belt_Equip")
		print("Attached to belt in inventory.gd")


func _on_Player_character_died():
	emit_signal("player_died")
