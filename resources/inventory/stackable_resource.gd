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
	if item == null:
		print("[ERROR] StackableResource.add_item: item is null")
		return
	
	print("[DEBUG] StackableResource.add_item: adding ", item, " to stack (current size: ", items_stacked.size(), ")")
	items_stacked.append(item)
	
	# Safety check for GameManager and player
	if GameManager.game == null or GameManager.game.player == null:
		print("[ERROR] StackableResource.add_item: GameManager or player is null")
		return
		
	if item.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM:
		GameManager.game.player.inventory.encumbrance += 1
	if item.item_size == GlobalConsts.ItemSize.SIZE_BULKY:
		GameManager.game.player.inventory.encumbrance += 2


## Will remove a EquipmentItem from the items_stacked and adjust the encumbrance for the player character
func remove_item(item: EquipmentItem) -> void:
	if item == null:
		print("[ERROR] StackableResource.remove_item: item is null")
		return
		
	print("[DEBUG] StackableResource.remove_item: removing ", item, " from stack (current size: ", items_stacked.size(), ")")
	items_stacked.erase(item)
	
	# Safety check for GameManager and player
	if GameManager.game == null or GameManager.game.player == null:
		print("[ERROR] StackableResource.remove_item: GameManager or player is null")
		return
		
	if item.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM:
		GameManager.game.player.inventory.encumbrance -= 1
	if item.item_size == GlobalConsts.ItemSize.SIZE_BULKY:
		GameManager.game.player.inventory.encumbrance -= 2


func _init() -> void:
	# Initialize the items_stacked array
	items_stacked = []
