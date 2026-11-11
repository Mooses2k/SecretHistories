extends SceneTree

## One-off probe for the screen-filter lane. Answers three questions with
## prints, then quits: (1) can a headless run load a #[compute] glsl resource
## and see SPIR-V bytecode, (2) is a real RenderingDevice present, (3) does a
## viewport capture in headless produce non-black pixels.

const PROBE_GLSL := "res://tests/tmp/probe_compute.glsl"


func _init() -> void:
	var iter := 0
	while Engine.get_main_loop() == null and iter < 20:
		await create_timer(0.01).timeout
		iter += 1

	var rd := RenderingServer.get_rendering_device()
	print("PROBE rd=", rd)

	var glsl: Resource = load(PROBE_GLSL)
	print("PROBE glsl=", glsl)
	if glsl is RDShaderFile:
		var spirv: RDShaderSPIRV = glsl.get_spirv()
		var bytecode: PackedByteArray = spirv.bytecode_compute
		var err: String = spirv.compile_error_compute
		print("PROBE bytecode_size=", bytecode.size(), " compile_error='", err, "'")

	# Render a trivially colorful frame and capture it.
	var scene := Node3D.new()
	get_root().add_child(scene)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.0, 3.0)
	scene.add_child(cam)
	cam.current = true
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.9, 0.4, 0.1)
	env.environment = e
	scene.add_child(env)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.6
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.8, 0.2)
	mesh.material_override = mat
	scene.add_child(mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation.x = -0.7
	scene.add_child(sun)

	for i in 6:
		await process_frame

	var dir := DirAccess.open("res://tests")
	if dir != null and not dir.dir_exists("tmp"):
		dir.make_dir("tmp")
	var img := get_root().get_texture().get_image()
	print("PROBE img=", img, " size=", img.get_size() if img != null else Vector2i.ZERO)
	if img != null:
		print("PROBE img_empty=", img.is_empty(), " format=", img.get_format())
		img.save_png("res://tests/tmp/probe_frame.png")
		print("PROBE saved res://tests/tmp/probe_frame.png")

	quit(0)
