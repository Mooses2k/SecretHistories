extends SceneTree

## Statue-lane copy of tests/run_gut_chunk.gd pointing at
## tests/gut_chunk_list_statue.gd. Exists because concurrent lanes rewrite the
## shared tests/gut_chunk_list.gd and a run can pick up someone else's chunk.

const CHUNK_LIST := preload("res://tests/gut_chunk_list_statue.gd")


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
	options["junit_xml_file"] = "res://tests/tmp/gut_chunk_statue_junit.xml"
	options["junit_xml_timestamp"] = false
	gut_config.options = options

	var runner = load("res://addons/gut/gui/GutRunner.tscn").instantiate()
	runner.set_gut_config(gut_config)
	get_root().add_child(runner)
	runner.run_tests()
