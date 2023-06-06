extends Node


# every room is a mix of its original purpose and its current use
# 30% of all rooms were originally empty, 60% of all rooms are currently unused

enum OriginalPurpose{
	EMPTY,
	ENTRY, # (2x2 max, 2+ doors) 
	ALCOVE, # (1x2 max, 1 door)
	CRYPT, # (1 door)
	CHAPEL,
	SHRINE, # (3x3 max)  
	MEDITATION_CHAMBER, # (2x2 max, 1 door, no wall lighting)
	STATUE_GALLERY,
	MUSEUM,
	BESTIARY,
	RECORD_ROOM, # (3x3 min)
	FOUNTAIN, # (2+ doors) 
	WELL # (2x2 max)
}

enum CurrentPurpose{
	UNUSED,
	KITCHEN, # (not well)
	PANTRY, # (3x3 max, 1 door, no wall lighting)
	STOREROOM, # (1 door)
	MESS_HALL, # (chooses biggest room)
	PRIVATE_DINING_ROOM, # (3x3 max, not well)
	GARBAGE_ROOM, # (no wall lighting) 
	STUDY, # (3x3 max, not well)
	LIBRARY, # (3x3 min, prefer records room)
	TEMPLE, # (3x3 min, prefer chapel)
	MEDITATION_CHAMBER, # (1 door, no wall lighting, prefer meditation_chamber) 
	LOUNGE, # (not well)
	BARRACKS, # (not well)
	PRIVATE_BEDROOM, # (3x3 max, not well)
	CLOSET, # (1 door, no wall lighting)
	GUARD_POST # (2x2 max, 2+ doors)
}

export var percent_empty_original_rooms = 0.3
export var percent_unused_current_rooms = 0.6


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
