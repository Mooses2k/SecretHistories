@tool
# Atmosphere weather group (issue #757).
# Atmosphere is PER FLOOR and OPTIONAL. Code reality: one GenerationManager
# generate() call builds exactly ONE floor (game.gd instantiates a fresh
# procedural_world per floor and calls create_world on each descent, and
# WorldData carries no floor index), so one roll per _execute_step call IS one
# roll per floor. Most floors are clean (no atmosphere); some floors are all
# fog with ONE variant; a few are all dust with ONE variant. Fog and dust
# never coexist. Children read the decision from their `weather_scene_path`
# property; empty means "clean floor, place nothing".
extends GenerationGroup

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

@export var fog_half_height_scene_path := "res://scenes/effects/fog_volume_effect_half_height.tscn"
@export var fog_swirl_scene_path := "res://scenes/effects/fog_volume_effect_swirl.tscn"
@export var fog_thick_scene_path := "res://scenes/effects/fog_volume_effect_thick.tscn"
@export var dust_scene_path := "res://scenes/effects/dust_volume_effect.tscn"
@export var flecks_scene_path := "res://scenes/effects/dust_volume_effect_flecks.tscn"
@export var plague_scene_path := "res://scenes/effects/dust_volume_effect_plague.tscn"

# Per-floor atmosphere distribution, owner confirmed:
# none=0.50, fog=0.35 (must stay less than half), dust=0.15.
# Variant inside a family is uniform.
@export var no_atmosphere_chance := 0.50
@export var fog_chance := 0.35
@export var dust_chance := 0.15

#--- private variables - order: export > normal var > onready -------------------------------------

var _rng := RandomNumberGenerator.new()

### -----------------------------------------------------------------------------------------------

### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	_rng.seed = generation_seed

	# One atmosphere decision for THIS floor; clean is the common case
	var weather_scene_path := ""
	var atmosphere_roll := _rng.randf()
	if atmosphere_roll < no_atmosphere_chance:
		weather_scene_path = ""
	elif atmosphere_roll < no_atmosphere_chance + fog_chance:
		match _rng.randi() % 3:
			0:
				weather_scene_path = fog_half_height_scene_path
			1:
				weather_scene_path = fog_swirl_scene_path
			_:
				weather_scene_path = fog_thick_scene_path
	else:
		match _rng.randi() % 3:
			0:
				weather_scene_path = dust_scene_path
			1:
				weather_scene_path = flecks_scene_path
			_:
				weather_scene_path = plague_scene_path

	# Route the path to the matching child only; the other child gets empty
	# (disabled), so fog and dust can never both be active on a floor.
	# Children declare their weather family via `accepts_fog_weather`.
	for child in get_children():
		if not (child is GenerationStep):
			continue
		var weather_is_fog := weather_scene_path.contains("fog_volume_effect")
		if child.get("accepts_fog_weather") == weather_is_fog:
			child.set("weather_scene_path", weather_scene_path)
		else:
			child.set("weather_scene_path", "")

	super._execute_step(data, gen_data, generation_seed)

### -----------------------------------------------------------------------------------------------

### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
