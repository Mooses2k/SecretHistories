@tool
## World-placement rest orientation for pickable items.
##
## Item scenes are authored in HELD pose (owner ruling), so most long weapons
## point up (+Y) with the grip at the bottom. When the world spawn path places
## an item on the floor or in a sarcophagus, this applies a rest-orientation
## offset so the item lies naturally instead of standing upright:
##
## - class_defaults: per-script-class default (melee weapons and guns get a
##   90 degree flip), keyed by the item script's global class name.
## - item_overrides: per-item values keyed by the full scene path, for items
##   whose held pose does not read correctly under the class default
##   (mace, pitchfork, halberd; values tunable per item without re-authoring
##   the held pose).
## - everything else (candles, bottles, books, bones, ...) gets identity.
##
## The offset is applied in item-local space (basis = basis * offset), so any
## yaw the generation steps authored (SpawnData.set_y_rotation and friends)
## is preserved. The equipped/in-hand look is untouched: EquipmentItem
## rewrites the equipped pose from HoldPosition every physics frame
## (equipment_item.gd _physics_process), and the held-pose transforms inside
## the item scenes are never modified here.
class_name PlacementOrientationData
extends Resource


### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const DEFAULT_TABLE_PATH := "res://resources/item_placement/placement_orientation_defaults.tres"

#--- public variables - order: export > normal var > onready --------------------------------------

## Rest orientation in degrees (X, Y, Z euler), keyed by item script global
## class name, e.g. "MeleeItem" or "GunItem".
@export var class_defaults: Dictionary = {}

## Per-item rest orientation in degrees (X, Y, Z euler), keyed by the full
## res:// scene path of the item scene. Wins over class_defaults.
@export var item_overrides: Dictionary = {}

#--- private variables - order: export > normal var > onready -------------------------------------

static var _default: PlacementOrientationData = null

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## The single shared data table the spawn path consults.
static func default_data() -> PlacementOrientationData:
	if _default == null:
		_default = load(DEFAULT_TABLE_PATH) as PlacementOrientationData
	return _default


## Applies the rest-orientation offset to an item about to be placed into the
## world by a spawn site. Call AFTER the spawn site has set the final
## position/yaw transform and BEFORE add_child. Items with no matching entry
## (and non-Node3D nodes) are left untouched.
static func apply_to_item(item: Node, scene_path: String) -> void:
	if item == null or not (item is Node3D):
		return
	var table := default_data()
	if table == null:
		return
	var offset_degrees: Vector3 = table.rest_offset_degrees_for(item, scene_path)
	if offset_degrees == Vector3.ZERO:
		return
	var radians := Vector3(
			deg_to_rad(offset_degrees.x),
			deg_to_rad(offset_degrees.y),
			deg_to_rad(offset_degrees.z)
	)
	var node3d := item as Node3D
	node3d.basis = node3d.basis * Basis.from_euler(radians)


## Resolves the rest offset in degrees for an item instance.
func rest_offset_degrees_for(item: Node, scene_path: String) -> Vector3:
	if item_overrides.has(scene_path):
		var override_value: Variant = item_overrides[scene_path]
		if override_value is Vector3:
			return override_value
		return Vector3.ZERO

	var item_script: Script = item.get_script()
	# Walk the inheritance chain so subclasses resolve their parent class
	# default (e.g. RevolverItem -> GunItem).
	while item_script != null:
		var global_name := String(item_script.get_global_name())
		if class_defaults.has(global_name):
			var default_value: Variant = class_defaults[global_name]
			if default_value is Vector3:
				return default_value
		item_script = item_script.get_base_script()
	return Vector3.ZERO

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
