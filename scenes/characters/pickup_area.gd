class_name PickupArea
extends Area3D

### Old top-down mode pickup area


var up_to_date: bool = false
var item_list : Array


# Updates the list of items in range, sorting them by distance
func update_item_list():
	for body in item_list:
		(body as Node).disconnect("tree_exiting", Callable(self, "item_removed"))
	item_list.clear()
	
	for body in get_overlapping_bodies():
		if body is PickableItem and body.is_inside_tree() and body.item_state == GlobalConsts.ItemState.DROPPED:
			item_list.push_back(body)
			body.connect("tree_exiting", Callable(self, "item_removed").bind(body), CONNECT_ONE_SHOT)
	
	for area in get_overlapping_areas():
		if area is Interactable:
#			print(area)
			item_list.push_back(area)
			area.connect("tree_exiting", Callable(self, "item_removed").bind(area), CONNECT_ONE_SHOT)
	
	item_list.sort_custom(Callable(self, "sort_items"))
	up_to_date = true


# Function used to sort items by distance, for 2 items a and b, returns 'true' if a is closer
# than b, returns false 'otherwise'
func sort_items(a : Node3D, b : Node3D):
	var a_dist = global_transform.origin.distance_squared_to(a.global_transform.origin)
	var b_dist = global_transform.origin.distance_squared_to(b.global_transform.origin)
	return a_dist <= b_dist


# Returns the list of items in range, updating it if necessary
func get_item_list():
	if not up_to_date:
		update_item_list()
	
	return item_list


func _physics_process(delta: float) -> void:
	up_to_date = false


func item_removed(item : Node):
#	item.disconnect("tree_exiting", self, "item_removed")
	self.item_list.erase(item)


func attempt_pickup(item : PickableItem):
	if (owner.inventory.can_add_item(item)):
		item.pickup(owner)
		owner.inventory.add_item(item)
