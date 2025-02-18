#extended only for class_name reasons
extends HumanoidCharacter
class_name Player


var inventory: InventoryManager

func _ready() -> void:
	GameManager.player = self
	inventory = $Inventory
	SignalBus.visibility_notifier_changed.connect(func(object: Node3D, visible_on_screen: bool):
		print(object)
		)
