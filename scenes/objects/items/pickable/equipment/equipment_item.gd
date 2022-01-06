extends PickableItem
class_name EquipmentItem

export var item_name : String = "Equipment"

func use():
	pass

func equip() -> void:
	if item_state != ItemState.EQUIPPED and !self.is_inside_tree():
		if owner_character != null:
			self.transform = Transform.IDENTITY
			owner_character.equipment_root.add_child(self)
			owner_character.inventory.current_equipment = self
			self.item_state = ItemState.EQUIPPED
		pass
	pass

func unequip() -> void:
	if item_state == ItemState.EQUIPPED:
		owner_character.inventory.current_equipment = null
		get_parent().remove_child(self)
		self.item_state = ItemState.INVENTORY # emits state changed signal
		pass
	pass
