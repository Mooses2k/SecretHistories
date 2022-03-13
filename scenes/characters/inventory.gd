extends Node
#class_name Inventory
signal hotbar_changed(slot)
signal current_slot_changed(previous, current)

const HOTBAR_SIZE : int= 10

# Items tracked exclusively by ammount, don't contribute to weight,
# don't show in hotbar
var tiny_items : Dictionary

# Usable items that appear in the hotbar
var hotbar : Array
var last_changed_slot : int = 0
var current_slot : int = 0 setget set_current_slot
var current_equipment : EquipmentItem = null
# Armor currently equipped by the character
var current_armor : Node
onready var drop_position_node : Spatial = owner.get_node("Body/DropPosition") as Spatial

func _ready():
	hotbar.resize(HOTBAR_SIZE)
	self.connect("hotbar_changed", self, "on_hotbar_changed")

func on_hotbar_changed(slot):
#	print(slot)
	last_changed_slot = slot
	pass

# Returns wether a given node can be added as an Item to this inventory
func can_add_item(item : PickableItem) -> bool:
	# Can only pickup dropped items
	# (may change later to steal weapons, or we can do that by dropping them first)
	if item.item_state != PickableItem.ItemState.DROPPED:
		return false
	# Can always pickup special items
	if item is TinyItem:
		return true
	# Can only pickup equipment if there's an empty hotbar slot
	if item is EquipmentItem and hotbar.has(null):
		return true
	return false

# Attempts to add a node as an Item to this inventory, returns 'true'
# if the attempt was successful, or 'false' otherwise
func add_item(item : PickableItem) -> bool:
	var can_add : bool = can_add_item(item)
#	print(can_add)
	if not can_add:
		return false
	var item_pickup_function_state = item.pickup(owner)
	if item_pickup_function_state:
		yield(item_pickup_function_state, "completed")
	if item is TinyItem and item.item_data != null:
		if not tiny_items.has(item.item_data):
			tiny_items[item.item_data] = 0
		tiny_items[item.item_data] += item.amount
		item.call_deferred("free")
	elif item is EquipmentItem:
		var slot : int = hotbar.find(null)
		hotbar[slot] = item
		if current_slot == slot:
			yield(item.equip(), "completed")
#			print("Equipping new item")
		emit_signal("hotbar_changed", slot)
	return true

func drop_hotbar_slot(slot : int) -> Node:
	var item = hotbar[slot]
	if not item == null:
		var item_node = item as EquipmentItem
		hotbar[slot] = null
		if current_equipment == item_node:
			yield(current_equipment.unequip(), "completed")
		if item_node:
			item_node.drop(drop_position_node.global_transform)
		emit_signal("hotbar_changed", slot)
	return item

func drop_current_item() -> Node:
	return drop_hotbar_slot(current_slot)

func set_current_slot(value : int):
	emit_signal("current_slot_changed", current_slot, value)

	if value != current_slot:
		current_slot = value
		if current_equipment != null:
			current_equipment.unequip()
			current_equipment = null
		if hotbar[current_slot]:
			hotbar[current_slot].equip()
