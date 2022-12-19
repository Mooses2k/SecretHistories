extends Node



# tags for objects: 
# 	CENTERPIECE, # looks best near center of room, wall, surface, etc
# 	BACK_AGAINST_WALL, # only place with back to wall
#	BACK_AGAINST_SIMILAR, # looks fine if put back-to-back with something similar height
# parts of a room
#	FLOOR, # typically found on a floor
#	WALL, # typically found on or hung from a wall
#	CEILING, # typically found on or hung from a ceiling
#	MOULDING, # a strip of material used to cover transitions between surfaces or for decoration
#	BASEBOARD, # aka 'skirting', type of moulding conceals junction of an interior wall and floor
#	CORNICE, # type of moulding connects wall to ceiling, maybe used to direct water away from wall
#	DOORWAY, # found on or in a doorway, like an engraving or part of a door latch
#	DOOR, # is on a door or part of a door
#	DOOR_HANDLE,
#	KEYHOLE, # found in a keyhole
#	PIT, # type of trap or otherwise a hole in the ground
# characters can lay on these
#	BED,
#	BUNKBED,
#	MAKES_SMOKE, # larger fire that will smoke up a place if not vented

export var place_first = false # important for room; any of these are placed before other things
export var must_have = false # if this isn't there at the end, regenerate the room


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
