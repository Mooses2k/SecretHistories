# Write your doc string for this file here
extends Spatial

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

enum PossibleLids {
	EMPTY,
	PLAIN,
	KNIGHT,
	SAINT,
}

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

export(PossibleLids) var current_lid := PossibleLids.EMPTY setget _set_current_lid

#--- private variables - order: export > normal var > onready -------------------------------------

var _current_lid_node: RigidBody = null

onready var _lid_scenes := $LidScenes as ResourcePreloader
onready var _lid_positions := {
		PossibleLids.PLAIN: $PositionPlain.translation,
		PossibleLids.KNIGHT: $PositionKnight.translation,
		PossibleLids.SAINT: $PositionSaint.translation,
}

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready() -> void:
	_spawn_lid()

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

static func get_random_lid_type(rng: RandomNumberGenerator) -> int:
	var chosen_lid := rng.randi() % PossibleLids.keys().size()
	return chosen_lid

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _spawn_lid() -> void:
	if _current_lid_node != null:
		remove_child(_current_lid_node)
		_current_lid_node.queue_free()
		_current_lid_node = null
	
	if current_lid == PossibleLids.EMPTY:
		return
	
	var packed_scene := _lid_scenes.get_resource(PossibleLids.keys()[current_lid]) as PackedScene
	_current_lid_node = packed_scene.instance() as RigidBody
	_current_lid_node.translation = _lid_positions[current_lid]
	add_child(_current_lid_node, true)


func _set_current_lid(value: int) -> void:
	if not value in PossibleLids.values():
		push_warning("%s is not a valid Lid value."%[value])
		value = posmod(value, PossibleLids.values().size())
	current_lid = value
	
	if is_inside_tree():
		_spawn_lid()

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
