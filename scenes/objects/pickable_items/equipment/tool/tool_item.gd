extends EquipmentItem;
class_name ToolItem




func _process(delta):
	if item_state == GlobalConsts.ItemState.DROPPED:
		$ignite/CollisionShape.disabled = false
	else:
		$ignite/CollisionShape.disabled = true
