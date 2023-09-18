extends Spatial


# TODO: Needs commenting
var light_level_bottom : float
var light_level_top : float

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
	
	# Bottom camera image
	var image : Image = get_node("ViewportContainer/Viewport").get_texture().get_data()
	
	light_level_bottom = _average(_build_pixel_array(image))
	
	# Top camera image
	image = get_node("ViewportContainer2/Viewport").get_texture().get_data() as Image
	
	light_level_top = _average(_build_pixel_array(image))
	
	# If one's higher than the other, make them equal to the highest
	if (light_level_bottom > light_level_top):
		light_level_top = light_level_bottom
		
	_modify_by_encumbrance()   # Now we multiply your light level by your encumbrance value (have medium and/or bulky items)
	_modify_by_state()   # Now we check crouching and if a light is in hand

	# Okay, you're crouching without a lit light-source in hand; that's cool, you're less visible
	light_level_top *= 0.7   # (1 - pow(1 - level, 5))   # Previous method led to being invisible while crouching next to candle
	
	# Finally we set the character's light_level
	owner.light_level = light_level_top
	
	_last_time_since_detect = _get_time()   # Tracked to reduce function calls for performance


func _build_pixel_array(image):
	var floats = []
	
	image.lock()
		
	for y in range(0, image.get_height()):
		for x in range(0, image.get_width()):
			var pixel = image.get_pixel(x,y)
			var light_value = (pixel.r + pixel.g + pixel.b) / 3
			floats.append(light_value)
	
	return floats


func _modify_by_encumbrance():
	if owner.inventory.encumbrance > 0:
		light_level_top *= 1 + (owner.inventory.encumbrance * 0.1)   # Typical range would be from 1.0 to 1.5


func _modify_by_state():
	if owner.state == owner.State.STATE_CROUCHING:
		# If holding a lit light-source, no crouching and hiding for you
		# So messy how this nest is required for this
		if owner.inventory.get_mainhand_item():
#			if owner.inventory.get_mainhand_item() is EmptyHand:
#				return
			if owner.inventory.get_mainhand_item() is CandleItem or owner.inventory.get_mainhand_item() is TorchItem or owner.inventory.get_mainhand_item() is CandelabraItem or owner.inventory.get_mainhand_item() is LanternItem:
				if owner.inventory.get_mainhand_item().is_lit == true:
					owner.light_level = light_level_top
					_last_time_since_detect = _get_time()   # Tracked to reduce function calls for performance
					return
		if owner.inventory.get_offhand_item():
#			if owner.inventory.get_offhand_item() is EmptyHand:
#				return
			if owner.inventory.get_offhand_item() is CandleItem or owner.inventory.get_offhand_item() is TorchItem or owner.inventory.get_offhand_item() is CandelabraItem or owner.inventory.get_offhand_item() is LanternItem:
				if owner.inventory.get_offhand_item().is_lit == true:
					owner.light_level = light_level_top
					_last_time_since_detect = _get_time()   # Tracked to reduce function calls for performance
					return


func _average(numbers: Array) -> float:
	var sum = 0.0
	for n in numbers:
		sum += n
	return sum / numbers.size()
