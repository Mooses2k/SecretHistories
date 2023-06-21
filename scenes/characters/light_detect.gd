extends Spatial


# TODO: Needs commenting
var level1 : float
var level : float

export var light_detect_interval : float = 0.25   # For performance, only check about 4 times a second
var _last_time_since_detect : float = 0.00


func _get_time() -> float:
	return OS.get_ticks_msec() / 1000.0


func _process(delta):
	# For performance, only check about 4 times a second
	if _last_time_since_detect + light_detect_interval > _get_time() and _last_time_since_detect != 0.0:
		return

#	var meshInstance := get_node("MeshInstance")
	var meshInstance2 := get_node("MeshInstance2")
	get_node("ViewportContainer/Viewport/Camera").global_transform.origin = (
			Vector3(meshInstance2.global_transform.origin.x,
			meshInstance2.global_transform.origin.y - .3, 
			meshInstance2.global_transform.origin.z))
	get_node("ViewportContainer2/Viewport/Camera").global_transform.origin = (
			Vector3(meshInstance2.global_transform.origin.x,
			meshInstance2.global_transform.origin.y + .3, 
			meshInstance2.global_transform.origin.z))
	
	var image : Image = get_node("ViewportContainer/Viewport").get_texture().get_data()
	var floats = []
	image.lock()
	
	for y in range(0, image.get_height()):
		for x in range(0, image.get_width()):
			var pixel = image.get_pixel(x,y)
			var light_value = (pixel.r + pixel.g + pixel.b) / 3
			floats.append(light_value)
		
	level1 = average(floats)
	
	image = get_node("ViewportContainer2/Viewport").get_texture().get_data() as Image
	floats.empty()
	image.lock()
		
	for y in range(0, image.get_height()):
		for x in range(0, image.get_width()):
			var pixel = image.get_pixel(x,y)
			var light_value = (pixel.r + pixel.g + pixel.b) / 3
			floats.append(light_value)
		
	level = average(floats)
	
	if (level1 > level):
		level = level1
	
	# If holding a lit light-source, no crouching and hiding for you
	# So messy how this nest is required for this
	if owner.inventory.get_mainhand_item():
		if owner.inventory.get_mainhand_item() is EmptyHand:
			return
		if owner.inventory.get_mainhand_item() is CandleItem or owner.inventory.get_mainhand_item() is TorchItem or owner.inventory.get_mainhand_item() is CandelabraItem or owner.inventory.get_mainhand_item() is LanternItem:
			if owner.inventory.get_mainhand_item().is_lit == true:
				owner.light_level = level
				return
	if owner.inventory.get_offhand_item():
		if owner.inventory.get_offhand_item() is EmptyHand:
			return
		if owner.inventory.get_offhand_item() is CandleItem or owner.inventory.get_offhand_item() is TorchItem or owner.inventory.get_offhand_item() is CandelabraItem or owner.inventory.get_offhand_item() is LanternItem:
			if owner.inventory.get_offhand_item().is_lit == true:
				owner.light_level = level
				return

	# Okay, you're crouching without a lit light-source in hand; that's cool, you're less visible
	if owner.state == owner.State.STATE_CROUCHING:
		level *= (1 - pow(1 - level, 5))
	
	# Now we multiply your light level by your encumbrance value (have medium and/or bulky items)
	if owner.inventory.encumbrance > 0:
		level *= 1 + (owner.inventory.encumbrance * 0.1)   # Typical range would be from 1.0 to 1.5
	
	# Finally we set the character's light_level
	owner.light_level = level
	
	_last_time_since_detect = _get_time()   # Tracked to reduce function calls for performance


func average(numbers: Array) -> float:
	var sum = 0.0
	for n in numbers:
		sum += n
	return sum / numbers.size()
