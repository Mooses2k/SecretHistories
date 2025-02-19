#extended only for class_name reasons
extends HumanoidCharacter
class_name Player


var inventory: InventoryManager

func _ready() -> void:
	GameManager.player = self
	inventory = $Inventory
	
