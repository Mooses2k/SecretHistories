extends PickableItem
class_name EquipmentItem


signal used_primary()
signal used_secondary()
signal used_reload()

export(GlobalConsts.ItemSize) var item_size : int = GlobalConsts.ItemSize.SIZE_MEDIUM

export var item_name : String = "Equipment"


# Override this function for (Left-Click and E, typically) use actions
func _use_primary():
	print("use primary")
	pass

# Right-click, typically
func _use_secondary():
	print("use secondary")
	pass


func _use_reload():
	print("use reload")
	pass


func use_primary():
	_use_primary()
	emit_signal("used_primary")
	pass


func use_secondary():
	_use_secondary()
	emit_signal("used_secondary")
	pass


func use_reload():
	_use_reload()
	emit_signal("used_reload")
	pass


func get_hold_transform() -> Transform:
	return $HoldPosition.transform.inverse()


# WORKAROUND for https://github.com/godotengine/godot/issues/62435
func _process(delta):
	if self.item_state == GlobalConsts.ItemState.EQUIPPED:
		transform = get_hold_transform()


#func equip(at : Node) -> void:
#	if item_state != ItemState.EQUIPPED and !self.is_inside_tree():
#		if owner_character != null:
#			self.transform = Transform.IDENTITY
#			at.call_deferred("add_child", self)
#			yield(self, "tree_entered")
#			self.transform = Transform.IDENTITY
#			self.force_update_transform()
#			owner_character.inventory.current_equipment = self
#			self.owner = owner_character
#			self.item_state = ItemState.EQUIPPED
#		pass
#	pass
#
#
#func unequip() -> void:
#	if item_state == ItemState.EQUIPPED:
#		owner_character.inventory.current_equipment = null
#		get_parent().call_deferred("remove_child", self)
#		yield(self, "tree_exited")
#		self.item_state = ItemState.INVENTORY # emits state changed signal
#		pass
#	pass
