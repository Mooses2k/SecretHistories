## Helpers for the start-game cheat menu's "Force Room Purpose" debug setting.
## The setting (enum, group "Generation Settings") names a room purpose that
## world generation must force-fit onto every floor while it is set:
## generate_rooms.gd guarantees one EMPTY room inside the purpose's size band,
## and generate_room_purposes.gd assigns the purpose to every compatible EMPTY
## room on the floor, ignoring max_amount. Everything here returns empty or
## unbounded values when the setting is absent (headless, editor, older saves)
## or set to OFF, so normal generation is untouched.
class_name ForceRoomPurpose
extends RefCounted


const SETTING_NAME := "Force Room Purpose"
const OFF_VARIANT := "OFF"


## Returns the selected purpose display name, or "" when the force is OFF or
## the setting does not exist. Takes the Game explicitly so callers guard
## GameManager.game themselves and tests can pass a stub.
static func get_forced_purpose_name(game: Game) -> String:
	if game == null:
		return ""
	return get_forced_purpose_name_from_settings(game.local_settings)


static func get_forced_purpose_name_from_settings(settings: SettingsClass) -> String:
	if settings == null or not settings.has_setting(SETTING_NAME):
		return ""
	if not settings.is_setting_enum(SETTING_NAME):
		return ""
	var variant_index: int = settings.get_setting(SETTING_NAME)
	var variants := settings.get_setting_variants(SETTING_NAME)
	if variant_index < 0 or variant_index >= variants.size():
		return ""
	var variant := str(variants[variant_index])
	return "" if variant == OFF_VARIANT else variant


## Display name of a purpose: its RoomData.OriginalPurpose enum key. The
## editor stores purpose_id as an int while the .tres files carry it as a
## digit string, so int() covers both representations.
static func get_purpose_display_name(purpose: RoomPurpose) -> String:
	return get_purpose_display_name_from_type(int(purpose.purpose_id))


## Display name of a RoomData.OriginalPurpose type value (enum key).
static func get_purpose_display_name_from_type(purpose_type: int) -> String:
	var purpose_names := RoomData.OriginalPurpose.keys()
	if purpose_type < 0 or purpose_type >= purpose_names.size():
		return ""
	return str(purpose_names[purpose_type])


## Smallest size the purpose accepts, per axis, in tiles. When several
## min-size requirements exist, the largest wins per axis.
static func get_required_min_size(purpose: RoomPurpose) -> Vector2i:
	var size := Vector2i.ZERO
	for item in purpose.requirements:
		var requirement := item as RequirementMinSize
		if requirement == null:
			continue
		size.x = max(size.x, requirement.min_x_tiles)
		size.y = max(size.y, requirement.min_y_tiles)
	return size


## Largest size the purpose accepts, per axis, in tiles; -1 means unbounded on
## that axis. When several max-size requirements exist, the smallest wins per
## axis. Doorway requirements are deliberately not resolved here: doors are
## placed later from the room graph, which connects every room, so the shipped
## purposes' doorway minimums (1) hold for any generated room.
static func get_required_max_size(purpose: RoomPurpose) -> Vector2i:
	var size := Vector2i(-1, -1)
	for item in purpose.requirements:
		var requirement := item as RequirementMaxSize
		if requirement == null:
			continue
		if size.x < 0:
			size.x = requirement.max_x_tiles
		else:
			size.x = min(size.x, requirement.max_x_tiles)
		if size.y < 0:
			size.y = requirement.max_y_tiles
		else:
			size.y = min(size.y, requirement.max_y_tiles)
	return size
