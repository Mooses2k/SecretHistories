extends Node3D
## Light-level sight producer (3.x scenes/characters/light_detection.gd).
## Two SubViewport cameras look down and up from the character body, sample
## the scene brightness around it, and publish owner.light_level after the
## 3.x modifiers (mainhand equipment, encumbrance, movement speed, crouch).
## The VisualSensor sight gate reads that property: at or below the sensor's
## light_sensitivity_level the character cannot be seen in darkness.
## 3.x authored the rig on the player rig only, so non-Player owners never
## render or sample here; their light_level stays at its default 0.0.

@export var light_detect_interval : float = 0.25   # sampled about 4 times a second

var light_level_bottom : float = 0.0
var light_level_top : float = 0.0
var _last_time_since_detect : float = 0.0


func _ready() -> void:
	# 3.x mounted this rig only on the player (player.tscn parent="Body");
	# the rig lives on the shared humanoid base here, so NPC owners must
	# neither render the sample viewports nor publish. The scene file carries
	# the converted Godot 3 update-mode value, so the player side pins
	# UPDATE_ALWAYS explicitly: the rig is authored invisible, which would
	# suppress a visibility-gated mode.
	if owner is Player:
		_bottom_viewport().render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_top_viewport().render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		_bottom_viewport().render_target_update_mode = SubViewport.UPDATE_DISABLED
		_top_viewport().render_target_update_mode = SubViewport.UPDATE_DISABLED
		set_process(false)


func _bottom_viewport() -> SubViewport:
	return get_node("SubViewportContainer/SubViewport") as SubViewport


func _top_viewport() -> SubViewport:
	return get_node("ViewportContainer2/SubViewport") as SubViewport


func _bottom_camera() -> Camera3D:
	return get_node("SubViewportContainer/SubViewport/Camera3D") as Camera3D


func _top_camera() -> Camera3D:
	return get_node("ViewportContainer2/SubViewport/Camera3D") as Camera3D


func _get_time() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_delta : float) -> void:
	# The sampler needs a renderer; headless runs have none and every
	# get_image() would just error on the dummy texture storage.
	if DisplayServer.get_name() == "headless":
		return

	# For performance, only check about 4 times a second
	if _last_time_since_detect != 0.0 and _last_time_since_detect + light_detect_interval > _get_time():
		return

	var mesh_instance_2 : Node3D = get_node("MeshInstance2")
	_bottom_camera().global_transform.origin = (
			Vector3(
				mesh_instance_2.global_transform.origin.x,
				mesh_instance_2.global_transform.origin.y - 0.3,
				mesh_instance_2.global_transform.origin.z))
	_top_camera().global_transform.origin = (
			Vector3(
				mesh_instance_2.global_transform.origin.x,
				mesh_instance_2.global_transform.origin.y + 0.3,
				mesh_instance_2.global_transform.origin.z))

	# Bottom camera image
	var image : Image = _bottom_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return   # no renderer on this tick (headless): skip the whole sample

	light_level_bottom = _average(_build_pixel_array(image))

	# Top camera image
	image = _top_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return   # no renderer on this tick (headless): skip the whole sample

	light_level_top = _average(_build_pixel_array(image))

	# If one's higher than the other, make them equal to the highest
	if light_level_bottom > light_level_top:
		light_level_top = light_level_bottom

	_modify_by_mainhand_equipment()   # multiply by the mainhand weapon factor
	_modify_by_encumbrance()   # multiply by the encumbrance value (medium and/or bulky items)
	_modify_by_speed()   # multiply by how fast the character is moving
	_modify_by_state()   # crouching hides, unless a lit light-source is in hand

	# Finally set the character's light_level
	_publish()

	_last_time_since_detect = _get_time()


## The single write seam into the character: extracted from _process so the
## publish can be pinned without rendering the sample viewports.
func _publish() -> void:
	owner.light_level = light_level_top


func _build_pixel_array(image : Image) -> Array[float]:
	var floats : Array[float] = []

	for y in range(0, image.get_height()):
		for x in range(0, image.get_width()):
			var pixel := image.get_pixel(x, y)
			var light_value := (pixel.r + pixel.g + pixel.b) / 3.0
			floats.append(light_value)

	return floats


func _modify_by_mainhand_equipment() -> void:
	var mainhand : EquipmentItem = owner.inventory.current_mainhand_equipment
	if is_instance_valid(mainhand):
		if mainhand is GunItem or mainhand is MeleeItem:
			light_level_top *= 1.1
		if mainhand.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM \
				or mainhand.item_size == GlobalConsts.ItemSize.SIZE_BULKY:
			light_level_top *= 1.1


func _modify_by_encumbrance() -> void:
	if owner.inventory.encumbrance > 0:
		light_level_top *= 1 + (owner.inventory.encumbrance * 0.1)   # typical range 1.0 to 1.5


func _modify_by_speed() -> void:
	if owner.linear_velocity.length() > 1:
		light_level_top *= owner.linear_velocity.length()


func _modify_by_state() -> void:
	# 3.x gated on owner.state == STATE_CROUCHING; the active humanoid tracks
	# crouch as a ratio, and the codebase already reads past-half as crouched
	# (the humanoid footstep branch).
	if owner.state.current_crouch_ratio > 0.5:
		# Crouching without a lit light-source in hand: less visible.
		light_level_top *= 0.7

		# If holding a lit light-source, no crouching and hiding: publish the
		# (still crouch-multiplied) level directly, 3.x quirk and all.
		if _is_holding_lit_light(owner.inventory.get_mainhand_item()):
			owner.light_level = light_level_top
			_last_time_since_detect = _get_time()
			return
		if _is_holding_lit_light(owner.inventory.get_offhand_item()):
			owner.light_level = light_level_top
			_last_time_since_detect = _get_time()
			return


func _is_holding_lit_light(item : EquipmentItem) -> bool:
	return (item is CandleItem or item is TorchItem or item is CandelabraItem
			or item is LanternItem) and item.is_lit


func _average(numbers : Array[float]) -> float:
	var sum : float = 0.0
	for value : float in numbers:
		sum += value
	return sum / numbers.size()
