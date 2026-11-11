@tool
# Generic resource that defines the rules for a room to fit a certain purpose
class_name RoomPurpose
extends Resource

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

# Fog assignment rule (owner ruling, fog rework follow-up): fog presence is
# keyed to the room TYPE, not rolled uniformly. Fountain and statue rooms are
# the often fogged ones; every other purpose stays at the small SOMETIMES
# chance; NEVER exists for types that must never fog. The enum stays for
# readability, but the presence chance itself is per-purpose data.
enum FogRule {
	NEVER, # this room type never gets fog
	SOMETIMES, # small default chance (see DEFAULT_FOG_CHANCE below)
	OFTEN, # carries its own explicit fog_chance (fountain, statue gallery)
}

#--- constants ------------------------------------------------------------------------------------

# Fallback fog presence chance for purposes with no explicit fog_chance (the
# SOMETIMES rule). OFTEN rooms carry their own number as data: fountain 0.95,
# statue gallery 0.5 (owner amendment "Statue 50% fog").
const DEFAULT_FOG_CHANCE : float = 0.08

#--- public variables - order: export > normal var > onready --------------------------------------

var purpose_id := ""

# a value of 0 means "unlimited"
var max_amount := 0
var requirements := []

# Room-specific ambience track (issue #179 music half). null means the room has
# no own track (fountain until its track exists): the shared Empty ambience
# stays the target. Owner ruling: purpose tracks do NOT mix with Empty, they
# are their own; entering the room crossfades to this stream, leaving
# crossfades back to Empty.
@export var ambient_stream : AudioStream = null

# How likely rooms of this purpose get fog weather. Read by the atmosphere
# group's per-room fog presence roll (owner: fountain/statue OFTEN, others
# SOMETIMES). Copied onto the RoomData when the purpose is assigned, so the
# weather rolls read the room, not the resource.
@export var fog_rule : FogRule = FogRule.SOMETIMES

# Per-purpose fog presence chance (owner amendment: the number is data, not a
# shared constant; fountain 0.95, statue 0.5). Purposes without an explicit
# chance fall back to DEFAULT_FOG_CHANCE. NEVER rooms never fog regardless.
@export_range(0.0, 1.0) var fog_chance : float = DEFAULT_FOG_CHANCE

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func is_compatible(room_data: RoomData) -> bool:
	var value = false
	
	for item in requirements:
		var requirement := item as RoomRequirements
		if requirement == null:
			continue
		
		value = requirement.has_fulfilled_requirement(room_data)
		if value == false:
			break
	
	return value

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

###################################################################################################
# Editor Methods ##################################################################################
###################################################################################################

### Custom Inspector built in functions -----------------------------------------------------------

func _get_property_list() -> Array:
	var properties: = []
	
	var enum_hint := ",".join(WorldData.OriginalPurpose.keys() as PackedStringArray)
	properties.append({
		name = "purpose_id",
		type = TYPE_INT,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		hint = PROPERTY_HINT_ENUM,
		hint_string = enum_hint
	})
	
	properties.append({
		name = "max_amount",
		type = TYPE_INT,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,1,1,or_greater"
	})
	
	properties.append({
		name = "requirements",
		type = TYPE_ARRAY,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		hint = PROPERTY_HINT_RESOURCE_TYPE,
		hint_string = "%s/%s:Resource"%[TYPE_OBJECT, TYPE_OBJECT]
	})
	
	properties.append({
		name = "fog_rule",
		type = TYPE_INT,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		hint = PROPERTY_HINT_ENUM,
		hint_string = ",".join(FogRule.keys() as PackedStringArray)
	})
	
	return properties

### -----------------------------------------------------------------------------------------------
