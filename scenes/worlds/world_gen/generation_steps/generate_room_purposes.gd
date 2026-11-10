@tool
# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

var purpose_resources := []

#--- private variables - order: export > normal var > onready -------------------------------------

var _rng := RandomNumberGenerator.new()

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, _gen_data : Dictionary, generation_seed : int):
	_rng.seed = generation_seed
	var forced_name := ForceRoomPurpose.get_forced_purpose_name(GameManager.game)
	var ordered_purposes := _purposes_with_forced_first(forced_name)
	var forced_purpose_matched := false
	for value in ordered_purposes:
		var purpose = value as RoomPurpose
		if purpose == null:
			continue

		var is_forced := (not forced_name.is_empty()) \
				and ForceRoomPurpose.get_purpose_display_name(purpose) == forced_name
		forced_purpose_matched = forced_purpose_matched or is_forced

		var valid_rooms := _get_valid_rooms(data, purpose)
		if valid_rooms.is_empty():
			if is_forced:
				push_warning("Force Room Purpose '%s': no compatible EMPTY room on the floor, nothing assigned."
					% [forced_name])
			continue

		var chosen_rooms := _get_chosen_rooms(purpose, valid_rooms, is_forced)
		for c_value in chosen_rooms:
			var room := c_value as RoomData
			room.type = purpose.purpose_id
			# Fog weather follows the room type (owner ruling): carry the
			# purpose's fog rule AND its per-purpose chance onto the room so
			# the atmosphere group's presence roll reads them.
			room.fog_rule = purpose.fog_rule
			room.fog_chance = purpose.fog_chance
			data.change_room_type(RoomData.OriginalPurpose.EMPTY, room.type, room)
			if is_forced:
				_print_forced_assignment(room)

	if not forced_name.is_empty() and not forced_purpose_matched:
		push_warning("Force Room Purpose '%s': no wired purpose resource carries that name, force-fit did nothing." % [forced_name])

	print("\n-- data.rooms:")
	for key in data.rooms:
		print("\t%s: %s"%[RoomData.OriginalPurpose.keys()[key], data.rooms[key].size()])
	print("-- END OF data.rooms\n")


# Debug force-fit: the forced purpose is processed before the others so it
# claims its rooms before competing purposes (the fountain fits the same
# 6x6..9x9 band) can take them. With no force active the order is exactly the
# wired order, so the OFF path keeps its behavior and rng draws.
func _purposes_with_forced_first(forced_name: String) -> Array:
	var ordered := []
	var forced := []
	for value in purpose_resources:
		var purpose := value as RoomPurpose
		if purpose == null:
			continue
		if not forced_name.is_empty() \
				and ForceRoomPurpose.get_purpose_display_name(purpose) == forced_name:
			forced.append(value)
		else:
			ordered.append(value)
	forced.append_array(ordered)
	return forced

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

func _get_valid_rooms(data: WorldData, purpose: RoomPurpose) -> Array:
	var valid_rooms := []
	
	var empty_rooms := data.get_rooms_of_type(RoomData.OriginalPurpose.EMPTY)
	for value in empty_rooms:
		var empty_room := value as RoomData
		if purpose.is_compatible(empty_room):
			valid_rooms.append(empty_room)
	
	return valid_rooms


func _get_chosen_rooms(purpose: RoomPurpose, valid_rooms: Array, is_forced := false) -> Array:
	var chosen_rooms := []

	# Debug force-fit: the setting overrides max_amount, so every compatible
	# EMPTY room on the floor carries the forced purpose. No rng draws on this
	# path; the step's rng is only used for the max_amount truncation below.
	if is_forced:
		return valid_rooms

	if purpose.max_amount > 0 and valid_rooms.size() > purpose.max_amount:
		for _index in purpose.max_amount:
				var chosen_index := _rng.randi() % valid_rooms.size()
				var chosen_room := valid_rooms[chosen_index] as RoomData
				chosen_rooms.append(chosen_room)
				valid_rooms.remove_at(chosen_index)
	else:
		chosen_rooms = valid_rooms

	return chosen_rooms


# Debug force-fit output: where the forced purpose landed on this floor. The
# owner reads these lines as the quick-check map for the forced rooms.
func _print_forced_assignment(room: RoomData) -> void:
	var floor_level := "unknown"
	if GameManager.game != null and "current_floor_level" in GameManager.game:
		floor_level = str(GameManager.game.current_floor_level)
	var center := Vector3(
			room.rect2.get_center().x * WorldData.CELL_SIZE,
			0.0,
			room.rect2.get_center().y * WorldData.CELL_SIZE)
	print("[ForceRoomPurpose] floor %s: %s assigned at cells %s, world center (%.1f, %.1f, %.1f)" % [
			floor_level,
			ForceRoomPurpose.get_purpose_display_name_from_type(room.type),
			room.rect2,
			center.x, center.y, center.z,
	])

### -----------------------------------------------------------------------------------------------

###################################################################################################
# Editor Methods ##################################################################################
###################################################################################################

### Custom Inspector built in functions -----------------------------------------------------------

func _get_property_list() -> Array:
	var properties: = []
	
	properties.append({
		name = "purpose_resources",
		type = TYPE_ARRAY,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		hint = PROPERTY_HINT_RESOURCE_TYPE,
		hint_string = "%s/%s:Resource"%[TYPE_OBJECT, TYPE_OBJECT]
	})
	
	return properties

### -----------------------------------------------------------------------------------------------
