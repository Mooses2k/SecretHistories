extends SceneTree

## One-off probe for the L screen-filter fix lane, part 2: can the real game
## side of the pipeline actually LOAD and COMPILE? Prints one line per check
## and quits: (1) every effect script loads (its preloads resolve), (2) every
## filter .glsl imports to non-empty SPIR-V with no compile error, (3) every
## texture the effects preload loads, (4) the whole ScreenFilterController
## script loads. Any FAIL line means _build_effects would abort in-game.

const EFFECT_SCRIPTS := [
	"res://scenes/screen_filters/screen_filter_color_reduce.gd",
	"res://scenes/screen_filters/screen_filter_psx.gd",
	"res://scenes/screen_filters/screen_filter_old_film.gd",
	"res://scenes/screen_filters/screen_filter_pixelate.gd",
	"res://scenes/screen_filters/screen_filter_dither.gd",
	"res://scenes/screen_filters/downsampler.gd",
	"res://scenes/screen_filters/screen_filter_controller.gd",
]

const FILTER_SHADERS := [
	"res://scenes/screen_filters/screen_filter_color_reduce.glsl",
	"res://scenes/screen_filters/screen_filter_psx.glsl",
	"res://scenes/screen_filters/screen_filter_old_film.glsl",
	"res://scenes/screen_filters/screen_filter_pixelate.glsl",
	"res://scenes/screen_filters/screen_filter_dither.glsl",
	"res://scenes/screen_filters/downsample.glsl",
]

const TEXTURES := [
	"res://resources/shaders/old_film/filmgrain.png",
	"res://resources/shaders/vignette/vignette.png",
	"res://resources/shaders/dither/assets/bayer2tile16.png",
	"res://resources/shaders/dither/assets/palette_eeve.png",
]


func _init() -> void:
	var iter := 0
	while Engine.get_main_loop() == null and iter < 40:
		await create_timer(0.05).timeout
		iter += 1

	var failed := false

	for path in EFFECT_SCRIPTS:
		var script : Script = load(path)
		if script == null:
			print("PROBE FAIL script ", path, " did not load")
			failed = true
			continue
		print("PROBE PASS script ", path, " (can_instantiate=", script.can_instantiate(), ")")

	for path in FILTER_SHADERS:
		var glsl : Resource = load(path)
		if glsl == null or not (glsl is RDShaderFile):
			print("PROBE FAIL shader ", path, " did not load as RDShaderFile")
			failed = true
			continue
		var spirv : RDShaderSPIRV = glsl.get_spirv()
		var bytecode : PackedByteArray = spirv.bytecode_compute
		var err : String = spirv.compile_error_compute
		var ok := bytecode.size() > 0 and err.is_empty()
		if not ok:
			failed = true
		print("PROBE ", ("PASS" if ok else "FAIL"), " shader ", path,
				" bytecode_size=", bytecode.size(), " compile_error='", err, "'")

	for path in TEXTURES:
		var tex : Resource = load(path)
		if tex == null:
			print("PROBE FAIL texture ", path, " did not load")
			failed = true
			continue
		print("PROBE PASS texture ", path)

	print("PROBE RESULT=", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
