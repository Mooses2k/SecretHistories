extends PickableItem
class_name EquipmentItem

export var item_name : String = "Equipment"
signal on_use()

#Override this function for use actions
func _use():
	pass

func use():
	_use()
	emit_signal("on_use")
	pass

func equip() -> void:
	if item_state != ItemState.EQUIPPED and !self.is_inside_tree():
		if owner_character != null:
			self.transform = Transform.IDENTITY
			owner_character.equipment_root.call_deferred("add_child", self)
			yield(self, "tree_entered")
			self.transform = Transform.IDENTITY
			self.force_update_transform()
			owner_character.inventory.current_equipment = self
			self.owner = owner_character
			self.item_state = ItemState.EQUIPPED
		pass
	pass

func _process(delta):
	if item_state == ItemState.EQUIPPED:
		transform = Transform.IDENTITY

func unequip() -> void:
	if item_state == ItemState.EQUIPPED:
		owner_character.inventory.current_equipment = null
		get_parent().call_deferred("remove_child", self)
		yield(self, "tree_exited")
		self.item_state = ItemState.INVENTORY # emits state changed signal
		pass
	pass
