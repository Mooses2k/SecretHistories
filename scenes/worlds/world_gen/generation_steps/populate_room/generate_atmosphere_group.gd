@tool
# Atmosphere weather group (issue #757).
# Two-level model. LEVEL 1, per floor: one roll picks the floor character,
# normal (most) / special all-fog / special all-dust. A special floor applies
# the family to EVERY real room; fog and dust never coexist.
# LEVEL 2: on a fog-type normal floor each room's fog PRESENCE is keyed to its
# ROOM TYPE (owner ruling, fog rework follow-up: no uniform per-room fog
# sprinkle). RoomPurpose.fog_rule + per-purpose fog_chance, copied onto
# RoomData when the purpose is assigned, decide the presence chance: the
# OFTEN rooms carry their own number as data (fountain 0.95, statue gallery
# 0.5 per the "Statue 50% fog" amendment), other types roll the small
# SOMETIMES fallback (0.08), NEVER rooms stay clean. When a room IS fogged
# its VARIANT is a weighted pick: LOW (floor-pool half-height) most, MEDIUM
# (swirl) less, FULL (thick) rarely. Staircase rooms and any type without a
# purpose resource keep the RoomData SOMETIMES fallback. Dust presence stays
# a uniform per-room roll. Within a room one variant only, never per-tile.
# Code reality: one GenerationManager generate() call builds exactly ONE floor
# (game.gd instantiates a fresh procedural_world per floor and calls
# create_world on each descent), so one roll per _execute_step call IS one
# roll per floor. Children read their decision from `weather_scene_path`
# (floor-wide, dust special floors) plus `room_paths` (per-room decisions);
# both empty means the child places nothing.
extends GenerationGroup

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

@export var fog_half_height_scene_path := "res://scenes/effects/fog_room_volume_half_height.tscn"
@export var fog_swirl_scene_path := "res://scenes/effects/fog_room_volume_swirl.tscn"
@export var fog_thick_scene_path := "res://scenes/effects/fog_room_volume_thick.tscn"
@export var dust_scene_path := "res://scenes/effects/dust_volume_effect.tscn"
@export var flecks_scene_path := "res://scenes/effects/dust_volume_effect_flecks.tscn"
@export var plague_scene_path := "res://scenes/effects/dust_volume_effect_plague.tscn"

# Per-floor character distribution, owner confirmed:
# normal=0.85, special all-fog=0.10, special all-dust=0.05.
@export var normal_floor_chance := 0.85
@export var special_fog_floor_chance := 0.10
@export var special_dust_floor_chance := 0.05

# Normal floors pick ONE family type, fog dominates.
@export var fog_type_chance := 0.8

# Fog VARIANT weighting when a room IS fogged (owner ruling: weight towards
# low floor-pool fog, maybe medium, rarely full). LOW is the floor-pool
# half-height volume, MEDIUM the swirl haze, FULL the thick volume.
const FOG_WEIGHT_LOW : float = 0.6
const FOG_WEIGHT_MEDIUM : float = 0.3
const FOG_WEIGHT_FULL : float = 0.1

# Per-room fog PRESENCE chance is per-purpose DATA on the room purpose
# resource (RoomPurpose.fog_chance -> RoomData.fog_chance; owner amendment
# "Statue 50% fog": the number lives on the .tres, not in a shared constant).
# Rooms with no purpose keep the SOMETIMES fallback baked into RoomData.

# Per-room dust presence on dust-type normal floors (uniform roll, unchanged).
@export var dust_room_chance := 0.08

#--- private variables - order: export > normal var > onready -------------------------------------

var _rng := RandomNumberGenerator.new()

### -----------------------------------------------------------------------------------------------

### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	# Vary per floor: mix the floor level into the roll seed so a fixed World
	# Seed does not roll the same atmosphere on every descent. Floor level is
	# negative (-1..-5); scale it with a prime to keep the hash spread wide.
	# Headless test harnesses may stub GameManager without a game; fall back
	# to the plain generation seed when the floor level is unavailable.
	var roll_seed := generation_seed
	if GameManager.game != null and "current_floor_level" in GameManager.game:
		roll_seed = generation_seed + GameManager.game.current_floor_level * 7919
	_rng.seed = roll_seed

	var fog_paths := {} # RoomData -> fog scene path
	var dust_paths := {} # RoomData -> dust scene path (normal floors)
	var dust_all_path := "" # non-empty on a special all-dust floor

	# LEVEL 1: one atmosphere decision for THIS floor.
	var floor_roll := _rng.randf()
	if floor_roll < normal_floor_chance:
		# LEVEL 2: normal floor, one family type. Fog presence is keyed to the
		# room type via RoomData.fog_rule; dust stays a uniform per-room roll.
		if _rng.randf() < fog_type_chance:
			for room in data.get_all_rooms():
				if room.type == WorldData.OriginalPurpose.EMPTY:
					continue
				if _rng.randf() < _fog_presence_chance(room):
					fog_paths[room] = _pick_fog_variant()
		else:
			for room in data.get_all_rooms():
				if room.type == WorldData.OriginalPurpose.EMPTY:
					continue
				if _rng.randf() < dust_room_chance:
					dust_paths[room] = _pick_dust_variant()
	elif floor_roll < normal_floor_chance + special_fog_floor_chance:
		# Special all-fog floor: every real room fogs, each with its own
		# weighted variant pick so a floor mixes the three heights.
		for room in data.get_all_rooms():
			if room.type == WorldData.OriginalPurpose.EMPTY:
				continue
			fog_paths[room] = _pick_fog_variant()
	else:
		dust_all_path = _pick_dust_variant()

	# Route each family's decision to the matching child only. Fog and dust
	# can never both be routed on a floor, so they can never coexist.
	# Children declare their weather family via `accepts_fog_weather`.
	for child in get_children():
		if not (child is GenerationStep):
			continue
		if child.get("accepts_fog_weather"):
			child.set("weather_scene_path", "")
			child.set("room_paths", fog_paths)
		else:
			child.set("weather_scene_path", dust_all_path)
			child.set("room_paths", dust_paths)

	super._execute_step(data, gen_data, generation_seed)


## Fog presence chance for one room: its per-purpose data chance, unless the
## rule is NEVER (owner: fog follows the room type, not a uniform sprinkle).
## Types without a purpose resource keep the RoomData SOMETIMES fallback.
func _fog_presence_chance(room : RoomData) -> float:
	if room.fog_rule == RoomPurpose.FogRule.NEVER:
		return 0.0
	return room.fog_chance


## Weighted fog variant pick when a room IS fogged: LOW most (0.6), MEDIUM
## less (0.3), FULL rarely (0.1). One randf draw, deterministic under roll_seed.
func _pick_fog_variant() -> String:
	var roll := _rng.randf()
	if roll < FOG_WEIGHT_LOW:
		return fog_half_height_scene_path
	if roll < FOG_WEIGHT_LOW + FOG_WEIGHT_MEDIUM:
		return fog_swirl_scene_path
	return fog_thick_scene_path


func _pick_dust_variant() -> String:
	match _rng.randi() % 3:
		0:
			return dust_scene_path
		1:
			return flecks_scene_path
		_:
			return plague_scene_path

### -----------------------------------------------------------------------------------------------

### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
