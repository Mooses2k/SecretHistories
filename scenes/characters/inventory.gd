class_name InventoryManager
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

# Dictionary of {int : int}, where the key is the key_id and the value is the amount of keys owned
# with that ID
var keychain : Dictionary

# Usable items that appear in the hotbar, as an array of nodes
var hotbar : Array[Node3D]

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

# Where to drop items from
@onready var Animations : AnimationPlayer = %AdditionalAnimations as AnimationPlayer


func _ready():
	hotbar.resize(HOTBAR_SIZE)
	current_offhand_slot = hands_free_slot


## Returns a boolean when a given node can be added as an Item to this inventory
func can_pickup_item(item : PickableItem) -> bool:
	# Can only pickup dropped items
	# (may change later to steal weapons, or we can do that by dropping them first)
	# Also prevents picking up busy items
	print("can_pickup_item called")
	if item.item_state == GlobalConsts.ItemState.DROPPED or item.item_state == GlobalConsts.ItemState.DAMAGING:
		print("item.item_state is ", item.item_state, ", so item is considered dropped or damaging")
		# Can always pick up equipment (goes to bulky slot if necessary)
		if item is EquipmentItem:
			return true
	# Can always pickup special items
	if (item is TinyItem) or (item is KeyItem):
		return true
	
	return false


## Attempts to add a node as an Item to this inventory, returns 'true' [br]
## if the attempt was successful, or 'false' otherwise
func add_item(item : PickableItem) -> bool:
	var can_pickup : bool = can_pickup_item(item)
	
	if not can_pickup:
		print("can't pick up")
		return false
	
	item.owner_character = owner
	print("item owner to be: ", item.owner_character)

	
	if item is TinyItem:
		if item.item_data != null:
			insert_tiny_item(item.item_data, item.amount)
			
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
	
	if item is EquipmentItem:
		# Update the inventory info immediately
		# This is a bulky item, or there is no space on the hotbar
		if item.item_size == GlobalConsts.ItemSize.SIZE_BULKY or !hotbar.has(null):
			drop_bulky_item()
			unequip_mainhand_item()
			unequip_offhand_item()
			equip_bulky_item(item)
			
			print("added bulky item")
			return true
		else:
			# Before anything, check if the item can be stacked on anything in the hotbar
			if _try_add_item_to_existing_stack(item) == true:
				print("added to stack")
				return true
			
			
			var target_slot: int = 0
			
			### Probably can be cleaned up - part 1 is to put lights offhand, part 2 is everything else
			### Part 1 - Checks if something is in offhand; if not, and the picking item is a light, put it in offhand
			if _item_is_light_source(item):
				if current_offhand_equipment == null or current_offhand_equipment is EmptyHand:
					if hotbar[target_slot] != null and !current_mainhand_slot:
						target_slot = current_offhand_slot
					if hotbar[target_slot] != null:
						target_slot = hotbar.find(null)
					if target_slot == current_mainhand_slot:
						target_slot += 1
					if target_slot != hands_free_slot:
						hotbar[target_slot] = item
						print("Light3D-source going to slot ", target_slot + 1)
						# Schedule the item removal from the world
						if item.is_inside_tree():
							item.get_parent().remove_child(item)
						
						emit_signal("hotbar_changed", target_slot)
						emit_signal("inventory_changed")
						
						if not bulky_equipment:
							set_offhand_slot(target_slot)   # This is what puts it in off-hand
							equip_offhand_item()
							return true   # Thus not processing the further autoequip logic below
			
			### Part 2 - Otherwise, normal rules: Select an empty slot, prioritizing the current one, if empty
			target_slot = current_mainhand_slot
			# Then the offhand, preferring this slot for lights
			if hotbar[target_slot] != null:
				print("Current hotbar slot, ", target_slot + 1, " is null. Setting slot to current offhand slot")
				target_slot = current_offhand_slot
			# Then the first empty slot
			if hotbar[target_slot] != null:
				target_slot = hotbar.find(null)
			# This checks if the slot to add the item isn't the hands-free slot then adds the item to the slot
			if target_slot != hands_free_slot:
				hotbar[target_slot] = item
				
				if item.stackable_resource != null:
					item.stackable_resource.add_item(item)
				# Schedule the item removal from the world
				if item.is_inside_tree():
					item.get_parent().remove_child(item)
				
				emit_signal("hotbar_changed", target_slot)
				emit_signal("inventory_changed")
				
				### Auto-equip
				var was_equipped: bool = _auto_equip_item(item, target_slot)
			
			# Encumbrance makes character louder and more visible. Character uses more stamina.
			# Eventually will affect mantling and swimming.
			if item.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM:
				encumbrance += 1
			if item.item_size == GlobalConsts.ItemSize.SIZE_BULKY:
				encumbrance += 2
				
			return true
	
	return false


# Functions to interact with tiny items

## Insert a tiny_item into the inventory, it also neeeds an amount, emits tiny_item_changed
func insert_tiny_item(item : TinyItemData, amount : int):
	if not tiny_items.has(item):
		tiny_items[item] = 0
	var prev = tiny_items[item]
	tiny_items[item] += amount
	var new = tiny_items[item]
	emit_signal("tiny_item_changed", item, prev, new)

## Remove a tiny_item from the inventory, it also neeeds an amount, emits tiny_item_changed
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

## Retrieves the amount of a tiny item in the invetory, if the item is not present, returns 0
func tiny_item_amount(item : TinyItemData) -> int:
	return 0 if not tiny_items.has(item) else tiny_items[item]

## Perfoms heavy logic to equip the mainhand_item, it uses the var current_mainhand_equipment
func equip_mainhand_item():
	await get_tree().create_timer(0.5).timeout
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
			
		item.set_item_state(GlobalConsts.ItemState.EQUIPPED)
		current_mainhand_equipment = item
		
		item.transform = item.get_hold_transform()
		if item.is_in_belt == true:
			remove_from_belt(item)
			item.get_parent().remove_child(item)
			owner.mainhand_equipment_root.add_child(item)
		else:
			owner.mainhand_equipment_root.add_child(item)
		emit_signal("inventory_changed")

## Perfoms heavy logic to unequip the mainhand_item, it uses the var current_mainhand_equipment
func unequip_mainhand_item():
	# temporary hack (issue #409)
	if not is_instance_valid(current_mainhand_equipment):
		current_mainhand_equipment = null
	
	if current_mainhand_equipment == null:   # No item equipped
		return
	
	#current_mainhand_equipment.set_item_state(GlobalConsts.ItemState.INVENTORY)
	emit_signal("unequip_mainhand")
	var item = current_mainhand_equipment
	current_mainhand_equipment = null
	if item.can_attach == true:
		pass
	else:
		item.get_parent().remove_child(item)

## Perfoms heavy logic to equip a bulky_item and clearing the player hands for it
func equip_bulky_item(item : EquipmentItem):
	# Clear any currently equipped items
	unequip_mainhand_item()
	unequip_offhand_item()
	drop_bulky_item()
	if item:
		item.set_item_state(GlobalConsts.ItemState.EQUIPPED)
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
		if item is CandleItem or item is TorchItem or item is CandelabraItem or item is LanternItem:
			print("Equipped offhand light item")
		else:
			print("Equipped offhand slot normal item")

	# Can't equip a Bulky Item simultaneously with a normal item
	drop_bulky_item()
	item.item_state = GlobalConsts.ItemState.EQUIPPED
	current_offhand_equipment = item
	# Waits for the item to exit the tree, if necessary
	item.transform = item.get_hold_transform()
	if item.is_in_belt == true:
		remove_from_belt(item)
		item.get_parent().remove_child(item)
		owner.offhand_equipment_root.add_child(item)
	else:
		owner.offhand_equipment_root.add_child(item)


func unequip_offhand_item():
	if current_offhand_equipment == null: # No item equipped
		return
	
	#current_offhand_equipment.set_item_state(GlobalConsts.ItemState.INVENTORY)
	# If the item was just equipped, waits for it to enter the tree before removing
	var item = current_offhand_equipment
	current_offhand_equipment = null
	emit_signal("unequip_offhand")
	if item.can_attach == true:
		pass
	else:
#		set_offhand_slot(10)
		if item != null:
			item.get_parent().remove_child(item)


func drop_mainhand_item():
	if bulky_equipment:
		drop_bulky_item()
	else:
		drop_hotbar_slot(current_mainhand_slot)


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
		
		if item_node.stackable_resource == null:
			hotbar[slot] = null
			if current_mainhand_equipment == item_node:
				unequip_mainhand_item()
			elif current_offhand_equipment == item_node:
				unequip_offhand_item()
			if item_node:
				if item_node.can_attach == true:
					remove_from_belt(item)
					item_node.get_parent().remove_child(item_node)
					_drop_item(item_node)
				else:
					_drop_item(item_node)
		else:
			item.stackable_resource.items_stacked.remove_at(0)
			var hand = null
			if item.stackable_resource.items_stacked.is_empty() == false:
				var next_item = item.stackable_resource.items_stacked[0]
				next_item.stackable_resource = item.stackable_resource
				hotbar[slot] = next_item
				
				# Prepare for the droping
				if current_mainhand_equipment == item_node:
					unequip_mainhand_item()
					hand = HandEnum.MAIN_HAND
				elif current_offhand_equipment == item_node:
					unequip_offhand_item()
					hand = HandEnum.OFF_HAND
				
				# Drop the item (it needed to be unequiped first)
				if item_node.can_attach == true:
					remove_from_belt(item)
					item_node.get_parent().remove_child(item_node)
					_drop_item(item_node)
				else:
					_drop_item(item_node)
				
				# Equip the new item of the stack
				match hand:
					HandEnum.MAIN_HAND:
						equip_mainhand_item()
					HandEnum.OFF_HAND:
						equip_offhand_item()
			else:
				hotbar[slot] = null
				if current_mainhand_equipment == item_node:
					unequip_mainhand_item()
				elif current_offhand_equipment == item_node:
					unequip_offhand_item()
				if item_node:
					if item_node.can_attach == true:
						remove_from_belt(item)
						item_node.get_parent().remove_child(item_node)
						_drop_item(item_node)
					else:
						_drop_item(item_node)
		emit_signal("hotbar_changed", slot)
	return item


## Drops the item, it must be unequipped first[br]
## Note that the drop is done in a deferred manner
func _drop_item(item : EquipmentItem):
	if owner is Player:
		if owner.player_controller.throw_state == owner.player_controller.ThrowState.SHOULD_PLACE:
			item.set_item_state(GlobalConsts.ItemState.DROPPED)   # At the moment, 'placed' items can't hurt anyone.
		elif owner.player_controller.throw_state == owner.player_controller.ThrowState.SHOULD_THROW:
			item.set_item_state(GlobalConsts.ItemState.DAMAGING)
		else:
			item.set_item_state(GlobalConsts.ItemState.DROPPED)   # Dropped for another reason like cycling away from bulky
			print("Dropped for another reason like cycling away from bulky")
	else:
		item.set_item_state(GlobalConsts.ItemState.DROPPED)   # This means, for now, non-players can't throw for damage; they drop when die
			
	if GameManager.game.level:   # This is for the real game
		if item.item_state == GlobalConsts.ItemState.DROPPED:   # Placed
			item.global_transform = owner.drop_position_node.global_transform
			print("Item set to DROPPED")
		if item.item_state == GlobalConsts.ItemState.DAMAGING:   # Thrown
			item.global_transform = owner.throw_position_node.global_transform
			print("Item set to DAMAGING")
				
		if item.can_attach == true:
#			item.get_parent().remove_child(item)
			GameManager.game.level.add_child(item)
		else:
			GameManager.game.level.add_child(item)
			print("Item added to level at position: ", item.global_position)
			
	
	elif !GameManager.game:   # This is here for test scenes
		if item.item_state == GlobalConsts.ItemState.DROPPED:   # Placed
			item.global_transform = owner.drop_position_node.global_transform
		if item.item_state == GlobalConsts.ItemState.DAMAGING:   # Thrown
			item.global_transform = owner.throw_position_node.global_transform
		
		find_parent("TestWorld").add_child(item)
		if item.item_state == GlobalConsts.ItemState.DAMAGING:
			item.apply_throw_logic()
			
	item.owner_character = null
		
	if item.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM:
		encumbrance -= 1
	if item.item_size == GlobalConsts.ItemSize.SIZE_BULKY:
		encumbrance -= 2


func set_mainhand_slot(value : int):
	if value != current_mainhand_slot:
#		if are_swapping == false:
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
#		if are_swapping == false:
		unequip_offhand_item()
		current_offhand_slot = value
		equip_offhand_item()
		emit_signal("offhand_slot_changed", previous_slot, value)
		emit_signal("inventory_changed")


# Equipment in each slot goes to other slot
func swap_slots(first_slot, second_slot):
	prints("Swapping slots ", first_slot, second_slot)
	# store both items in temp
	var first_temp = hotbar[first_slot]
	print(first_temp)
	var second_temp = hotbar[second_slot]
	print(second_temp)
	# place first item in final slot
	hotbar[second_slot] = first_temp
	print(hotbar[second_slot])
	# place second item in initial slot
	hotbar[first_slot] = second_temp
	print(hotbar[first_slot])
	
	# TODO: equip as appropriate or change current slot numbers for each hand
		# if each item is currently in a hand, swap_hands()?
	
	# null out the temp - not needed and breaks code
	#if is_instance_valid(first_temp):
		#first_temp.queue_free()
	#if is_instance_valid(second_temp):
		#second_temp.queue_free()
	
	emit_signal("inventory_changed") # this do anything?
	emit_signal("hotbar_changed", first_slot)
	emit_signal("hotbar_changed", second_slot)


# Equipment in each hand goes to other hand
func swap_hands():
	print("Swapping hands")
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
	print("Mainhand slot: ", current_mainhand_slot)
	print("Offhand slot: ", current_offhand_slot)
	
	# Avoids a bug if offhand is empty when swap where you can't pick anything up anymore after it 
	if current_offhand_slot == hands_free_slot:
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


func switch_away_from_light(light_source):
	if not light_source.can_attach:
		if not are_swapping and owner.player_controller.throw_state != owner.player_controller.ThrowState.SHOULD_PLACE and owner.player_controller.throw_state != owner.player_controller.ThrowState.SHOULD_THROW:
			print("unlighting light when putting it away because not swapping hands now")
			light_source.unlight()
	elif light_source.can_attach and light_source is LanternItem:
		attach_to_belt(light_source)


func attach_to_belt(item):
	if item.get_parent() != owner.belt_position:
		item.mesh_instance.visible = false
		item.is_in_belt = true
		item.get_parent().remove_child(item)
		owner.belt_position.add_child(item)
		belt_item = item
		$"%AdditionalAnimations".play("Belt_Equip")
		print("Attached to belt in inventory.gd")


func remove_from_belt(item):
	item.mesh_instance.visible = true
	item.is_in_belt = false
	belt_item = null
	print("Removed from belt in inventory.gd")


func _on_Player_character_died():
	emit_signal("player_died")



## Checks for a existing stack for a given item, returns true if the item was succesfully added to a stack
func _try_add_item_to_existing_stack(item_to_stack: EquipmentItem) -> bool:
	for hotbar_item: EquipmentItem in hotbar:
		if hotbar_item == null: continue # go to next hotbar_item if null
		
		if hotbar_item.stackable_resource != null and item_to_stack.stackable_resource != null and hotbar_item.stackable_resource.stack_name == item_to_stack.stackable_resource.stack_name:
			print("the item can stack with: " + hotbar_item.name)
			if hotbar_item.stackable_resource.items_stacked.size() == hotbar_item.stackable_resource.max_stack:
				print("... but its at full capacity rn")
				return false
			
			print("Hurray! Stacking boois")
			hotbar_item.stackable_resource.add_item(item_to_stack)
			_remove_item_from_world(item_to_stack)
			
			emit_signal("inventory_changed")
			return true
	
	return false
	

## Util func to defer the item removal from world space
func _remove_item_from_world(item: EquipmentItem) -> void:
	# Schedule the item removal from the world
	if item.is_inside_tree():
		item.get_parent().remove_child(item)


func _item_is_light_source(item: PickableItem) -> bool:
	if item is CandleItem or item is TorchItem or item is CandelabraItem or item is LanternItem :
		return true
	else:
		return false

## func used when adding a item to the inventory
func _auto_equip_item(item: EquipmentItem, target_slot: int) -> bool:
	# Autoequip if possible - main idea is prefer lights in off-hand and never forceably
	# put a medium gun in hand if it means pushing out a (lit) light-sourcecunt
	# (we currently don't check if it's lit)
	if current_mainhand_slot == target_slot and not bulky_equipment:
		print("current slot is added item slot, which is ", target_slot + 1)
		if current_offhand_equipment is LanternItem or current_offhand_equipment is CandleItem or current_offhand_equipment is TorchItem or current_offhand_equipment is CandelabraItem:
			print("...and current offhand is a light")
			if item.item_size == GlobalConsts.ItemSize.SIZE_SMALL:
				equip_mainhand_item()
				print("...and picked up item is a small item")
				return true
			if item.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM and item is MeleeItem:
				equip_mainhand_item()
				print("...and picked up item is a medium melee weapon")

		elif item.item_size == GlobalConsts.ItemSize.SIZE_SMALL:
			equip_mainhand_item()
			print("...and picked up item is a small item")
			return true
		
		# Medium items
		elif item.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM:
			equip_mainhand_item()
			return true
		
	elif current_offhand_slot == target_slot and not bulky_equipment and item.item_size == GlobalConsts.ItemSize.SIZE_SMALL:
		equip_offhand_item()
		return true
	
	return false
