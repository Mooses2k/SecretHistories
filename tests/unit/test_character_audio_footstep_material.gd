extends GutTest
## The footstep material parameter must reach the audio clip selection:
## play_footstep_sound with Carpet/Gravel picks clips from the matching
## folder, and resolve_footstep_material maps the level's WorldData surface
## types (3.x source) to footstep materials, defaulting to Stone.

const CHARACTER_AUDIO_SCRIPT := "res://scenes/characters/character_audio.gd"
const CARPET_DIR := "res://resources/sounds/footsteps/carpet_footsteps/"
const GRAVEL_DIR := "res://resources/sounds/footsteps/gravel_footsteps/"
const STONE_DIR := "res://resources/sounds/footsteps/stone_footsteps/"

var _audio : Node3D
var _saved_game : Game


func before_each() -> void:
	_audio = Node3D.new()
	_audio.set_script(load(CHARACTER_AUDIO_SCRIPT))
	for child_name in ["Speech", "Manipulation", "Movement"]:
		var player := AudioStreamPlayer3D.new()
		player.name = child_name
		_audio.add_child(player)
	add_child_autofree(_audio)
	_saved_game = GameManager.game


func after_each() -> void:
	if is_instance_valid(_audio):
		_audio.movement_audio.stop()
	GameManager.game = _saved_game


func test_footstep_material_carpet_selects_carpet_clips() -> void:
	_audio.play_footstep_sound(5.0, 1.0, 0.0, AudioLibrary.FOOTSTEP_TYPES.CARPET)
	var movement : AudioStreamPlayer3D = _audio.movement_audio
	assert_true(String(movement.stream.resource_path).begins_with(CARPET_DIR),
		"the carpet material plays a carpet footstep clip")


func test_footstep_material_gravel_selects_gravel_clips() -> void:
	_audio.play_footstep_sound(5.0, 1.0, 0.0, AudioLibrary.FOOTSTEP_TYPES.GRAVEL)
	var movement : AudioStreamPlayer3D = _audio.movement_audio
	assert_true(String(movement.stream.resource_path).begins_with(GRAVEL_DIR),
		"the gravel material plays a gravel footstep clip")


func test_footstep_material_stone_selects_stone_clips() -> void:
	_audio.play_footstep_sound(5.0, 1.0, 0.0, AudioLibrary.FOOTSTEP_TYPES.STONE)
	var movement : AudioStreamPlayer3D = _audio.movement_audio
	assert_true(String(movement.stream.resource_path).begins_with(STONE_DIR),
		"the stone material plays a stone footstep clip")


func test_resolve_defaults_to_stone_without_a_level() -> void:
	GameManager.game = null
	assert_eq(_audio.resolve_footstep_material(Vector3.ZERO),
		AudioLibrary.FOOTSTEP_TYPES.STONE,
		"no game means the Stone default")


func test_resolve_maps_world_surface_types_to_materials() -> void:
	var world_data : WorldData = WorldData.new()
	world_data.world_size_x = 4
	world_data.world_size_z = 4
	world_data.cell_count = 16
	world_data.cell_surface_type.resize(16)
	world_data.set_cell_surfacetype(world_data.get_cell_index_from_int_position(0, 0), WorldData.SurfaceType.CARPET)
	world_data.set_cell_surfacetype(world_data.get_cell_index_from_int_position(1, 0), WorldData.SurfaceType.GRAVEL)
	world_data.set_cell_surfacetype(world_data.get_cell_index_from_int_position(2, 0), WorldData.SurfaceType.STONE)
	world_data.set_cell_surfacetype(world_data.get_cell_index_from_int_position(3, 0), WorldData.SurfaceType.WOOD)
	var level : GameWorld = GameWorld.new()
	level.world_data = world_data
	var game : Game = Game.new()
	game.level = level
	GameManager.game = game

	var cell_size := WorldData.CELL_SIZE
	var center_offset := cell_size * 0.5
	assert_eq(_audio.resolve_footstep_material(Vector3(0 * cell_size + center_offset, 0.0, center_offset)),
		AudioLibrary.FOOTSTEP_TYPES.CARPET, "a carpet surface cell resolves to Carpet")
	assert_eq(_audio.resolve_footstep_material(Vector3(1 * cell_size + center_offset, 0.0, center_offset)),
		AudioLibrary.FOOTSTEP_TYPES.GRAVEL, "a gravel surface cell resolves to Gravel")
	assert_eq(_audio.resolve_footstep_material(Vector3(2 * cell_size + center_offset, 0.0, center_offset)),
		AudioLibrary.FOOTSTEP_TYPES.STONE, "a stone surface cell resolves to Stone")
	assert_eq(_audio.resolve_footstep_material(Vector3(3 * cell_size + center_offset, 0.0, center_offset)),
		AudioLibrary.FOOTSTEP_TYPES.STONE, "a surface without footstep clips (wood) defaults to Stone")
	assert_eq(_audio.resolve_footstep_material(Vector3(1000.0, 0.0, 1000.0)),
		AudioLibrary.FOOTSTEP_TYPES.STONE, "an out-of-bounds position defaults to Stone")
