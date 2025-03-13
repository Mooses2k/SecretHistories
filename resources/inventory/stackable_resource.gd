extends Resource
## This resource represents a stackable EquipementItem[br]
## To use it, just create a resource of type StackableResource, define the properties and attach on each scene/equipment you want to stack
class_name StackableResource


## A nickname for the stack, not used in code currently
@export var stack_name: String

## The max items this stack can hold
@export var max_stack: int

## Array of current stacked items
var items_stacked: Array[EquipmentItem]


## Will add a EquipmentItem to the items_stacked and calculate the emcubrance for the player character
func add_item(item: EquipmentItem) -> void:
	items_stacked.append(item)
	if item.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM:
		GameManager.game.player.inventory.encumbrance += 1
	if item.item_size == GlobalConsts.ItemSize.SIZE_BULKY:
		GameManager.game.player.inventory.encumbrance += 2


func _init() -> void:
	for i in items_stacked.size():
		items_stacked.remove_at(i)
