class_name PlacementAnchor
extends Marker3D


enum PlacementTags {
# generic placement
	SURFACE, # has a flattish space to set something
	HANGING, # something can hang from here
	STACKABLE_VERTICAL, # looks good if the same thing is stacked on top
	STACKABLE_HORIZONTAL, # looks good if the same thing is stacked next to it
# characters can sit on these
	SEATING, # can reasonable sit on these
	CHAIR, # place only single-seat seating here
	STOOL, # place small single-seal seating here
	BENCH, # can place multi-seat seating here
	PEW, # or should this be BENCH & RELIGIOUS or SEATING & LARGE & RELIGIOUS?
# relating to eating
	COMESTIBLE, # food, drink, consumables you can put in your mouth
	POTION,
	FOOD,
	DRINK,
	PLACE_SETTING, # set dishes for eating
	PLATE,
	BOWL,
	UTENSILS,
	FORK,
	KNIFE,
	SPOON,
	PLATTER,
	CUTTING_BOARD,
	POT,
	PAN,
	PANTRY,
	LARDER,
	CUPBOARD,
	KITCHEN_PREP, # chopping and prep before heating
	COOKING, # boiling, grilling, baking, etc
	FIRE_IN_FLAMES, # can be in fire like firewood, cauldron, etc
	FIRE_NEARBY, # fire-safe objects found near fires like iron pokers, tongs, etc
# other furniture types
	TABLE, # multi-purpose raised surface
	DESK, # table plus storage typically for working or reading
	DRESSER, # clothes storage with drawers
	WARDROBE,
	CONSOLE_TABLE, # smaller storage table with little depth for smaller spaces
	SIDE_TABLE, # typically found next to seating or beside a bed
	GLOBE,
	ASTROLABE,
	TELESCOPE,
	SOFA,
	ALTAR,
	PEDESTAL,
	SHRINE, # compact, mostly self-contained religious presentation
	STATUE,
	SHELF,
	BOOKCASE,
# containers
	STORAGE,
	CONTAINER,
	DRY,
	LIQUID,
	POWDER,
	CRATE,
	BARREL,
	SACK,
	BOX,
	BIN,
	CHEST,
	FOOTLOCKER,
	COFFER,
	LUGGAGE,
	HAT_CASE,
	SUITCASE,
	BRIEFCASE,
	TRUNK,
	BOTTLE,
	JUG,
	JAR,
	POUCH, # this could be SACK & SMALL
# activity types other than eating
	BAR, # booze and such
	CLEANING, # cleaning things
	BATHING, # cleaning characters
	WRITING, # pens, ink, stamps, etc
	PAINTING,
	WORKING, # making stuff
	MINING,
# objects
	BOOK, # manuscripts and published books
	JOURNAL, # diary of someone who was or is here
	NOTE, # memo or note or other written ephemera
	SCROLL, # single-use magical spell
	TROPHY_OR_CURIO, # an oddity or curiosity or otherwise unusual decorative piece
	STRANGE_DEVICE, # wand or other wondrous item, unknown contraption with powerful ability
	BEDDING, # sheets, blankets
	CLOTHING, # items that can be worn
	ARMOR, # these worn items protect more than modesty
	WEAPON, # melee or ranged
	MELEE,
	RANGED, # firearms, thrown weapons, bows, and throwers
	FIREARM,
	CLOCK, # can tell the time
	RUBBLE, # trash, ruin, collapse, broken furniture, animal remains, dirt, etc
	COFFIN, # place to store a dead body, coffins and sarcophagi etc
	CORPSE, # recently dead
	MUMMY, # long dead, preserved
	SKELETON, # long dead, unpreserved
	TOMB, # tomb contents, burial goods, found in a tomb
	BATHTUB,
# aspect of object
	LARGE, # a large plate would be a serving platter; a big bed would be a double/queen/king bed
	SMALL, # a small plate would be a small, side plate; a small bed would be a single
	VALUABLE,
	ROTTEN,
	BREAKABLE,
	EXPLOSIVE, # goes boom
	FLAMMABLE, # can be burnt
	ON_FIRE, # is being burnt
	BURNT, # has been burnt
	BROKEN, # heavily damaged, smashed, non-functional
	DIRTY, # not clean
	FANCY, # nicer than average
	PRIVATE, # found in private room
	SHARED, # found in shared rooms such as barracks
	DRAIN, # liquid- and gas-passable exit
	VENT, # gas-passable exit like a chimney
	TRAP, # an obstacle meant to hinder and/or harm
	TIDY, # no 20% fudge factor in placement
	UNTIDY, # moved much more, maybe knocked over
	RELIGIOUS,
	EFFIGY,
# faction relation
	BEAST, # pertaining to non-sapient animals
	HUMAN, # homo sapiens
	CHRISTIAN, # religious affiliation of the former monks of this place
	FIFTHIST, # pertaining to the Fifth Church
	DOA, # pertaining to the DoA
	IAD, # pertaining to IADs
	THE_PEOPLE, # pertaining to The People
	DGD # pertaining to the DGD
}

@export var allowed_tags : Array[PlacementTags] # (Array, PlacementTags)
@export var forbidden_tags : Array[PlacementTags] # (Array, PlacementTags)

@export var anchor_fill_probability = 1.0 # percent chance that an anchor slot will be filled
@export var min_quantity_wanted = 1 # we want at least this many
@export var max_quantity_wanted = 1 # we want no more than this many

@export var allow_recursive = true


func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
