extends SceneTree

## Screen-filter lane verification: the three ported compute shaders must be
## importable with non-empty SPIR-V bytecode and no compile errors. Prints
## one PROBE line per shader (text truth) and quits nonzero on any failure.

const SHADERS := [
	"res://scenes/screen_filters/screen_filter_old_film.glsl",
	"res://scenes/screen_filters/screen_filter_pixelate.glsl",
	"res://scenes/screen_filters/screen_filter_dither.glsl",
]


func _init() -> void:
	var iter := 0
	while Engine.get_main_loop() == null and iter < 20:
		await create_timer(0.01).timeout
		iter += 1
	var failed := false
	for path in SHADERS:
		var glsl: Resource = load(path)
		if glsl == null:
			print("PROBE FAIL ", path, " did not load")
			failed = true
			continue
		var spirv: RDShaderSPIRV = glsl.get_spirv()
		var bytecode: PackedByteArray = spirv.bytecode_compute
		var err: String = spirv.compile_error_compute
		var ok := bytecode.size() > 0 and err.is_empty()
		if not ok:
			failed = true
		print("PROBE ", ("PASS" if ok else "FAIL"), " ", path,
				" bytecode_size=", bytecode.size(), " compile_error='", err, "'")
	quit(1 if failed else 0)
