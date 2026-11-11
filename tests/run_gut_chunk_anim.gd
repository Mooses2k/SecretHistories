extends SceneTree

## Private copy of tests/run_gut_chunk.gd for the reload animation lane:
## reads this lane's list from tests/gut_chunk_list_anim.gd and writes a
## private junit file, so other lanes can run chunks concurrently without
## clobbering each other. Not a test; it runs the tests.

const CHUNK_LIST := preload("res://tests/gut_chunk_list_anim.gd")


func _init() -> void:
	var loader = load("res://addons/gut/gut_loader.gd")
	var max_iter := 20
	var iter := 0
	while(Engine.get_main_loop() == null and iter < max_iter):
		await create_timer(0.01).timeout
		iter += 1

	if(Engine.get_main_loop() == null):
		push_error("Chunk runner: main loop did not start in time.")
		quit(1)
		return

	var gut_config = load("res://addons/gut/gut_config.gd").new()
	var options: Dictionary = gut_config.default_options.duplicate()
	options["tests"] = CHUNK_LIST.SCRIPTS
	options["should_exit"] = true
	options["junit_xml_file"] = "res://tests/tmp/gut_chunk_junit_anim.xml"
	options["junit_xml_timestamp"] = false
	gut_config.options = options

	var runner = load("res://addons/gut/gui/GutRunner.tscn").instantiate()
	runner.set_gut_config(gut_config)
	get_root().add_child(runner)
	runner.run_tests()
