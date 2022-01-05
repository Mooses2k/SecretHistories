extends Node
#class_name Inventory

const HOTBAR_SIZE : int= 10

# Items tracked exclusively by ammount, don't contribute to weight,
# don't show in hotbar
var special : Dictionary

# Usable items that appear in the hotbar
var hotbar : Array
var last_changed_slot : int = 0
var current_slot : int = 0

# Armor currently equipped by the character
var current_armor : Node
onready var drop_position_node : Spatial = owner.get_node("DropPosition") as Spatial

func _ready():
	hotbar.resize(HOTBAR_SIZE)

# Returns wether a given node can be added as an Item to this inventory
func can_add_item(item : PickableItem) -> bool:
	# Can only pickup dropped items
	# (may change later to steal weapons, or we can do that by dropping them first)
	if item.item_state != PickableItem.ItemState.DROPPED:
		return false
	# Can always pickup special items
	if item is SpecialItem:
		return true
	# Can only pickup equipment if there's an empty hotbar slot
	if item is EquipmentItem and hotbar.has(null):
		return true
	return false

# Attempts to add a node as an Item to this inventory, returns 'true'
# if the attempt was successful, or 'false' otherwise
func add_item(item : PickableItem) -> bool:
	var can_add : bool = can_add_item(item)

	if not can_add:
		return false

	item.pickup(owner)

	if item is SpecialItem and item.item_data != null:
		if not special.has(item.item_data):
			special[item.item_data] = 0
		special[item.item_data] += item.amount
		item.free()

	elif item is EquipmentItem:
		var slot : int = hotbar.find(null)
		hotbar[slot] = item
		last_changed_slot = slot

	return true

func drop_hotbar_slot(slot : int) -> Node:
	var item = hotbar[slot]
	if not item == null:
		var item_node = item as EquipmentItem
		hotbar[slot] = null
		if item_node:
			item_node.drop(drop_position_node.global_transform)
		last_changed_slot = slot

	return item

func drop_current_item() -> Node:
	return drop_hotbar_slot(current_slot)
