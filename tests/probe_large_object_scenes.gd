extends SceneTree

## Headless load probe for the touched large object scenes: instantiates each
## scene, prints the root script and body type, then quits. Zero script errors
## is the pass condition.

const SCENES := [
	"res://scenes/objects/large_objects/debris/dirt_pile1.tscn",
	"res://scenes/objects/large_objects/fire/firepit.tscn",
	"res://scenes/objects/large_objects/pedestal/pedestal.tscn",
	"res://scenes/objects/large_objects/statuary/statue_angel_headless.tscn",
	"res://scenes/objects/large_objects/statuary/statue_gargoyle_2.tscn",
	"res://scenes/objects/large_objects/statuary/statue_angel_1.tscn",
]

func _init() -> void:
	var failures := 0
	for scene_path : String in SCENES:
		var packed : PackedScene = load(scene_path)
		if packed == null:
			printerr("LOAD FAIL: ", scene_path)
			failures += 1
			continue
		var node := packed.instantiate()
		if node == null:
			printerr("INSTANTIATE FAIL: ", scene_path)
			failures += 1
			continue
		var script_name := ""
		if node.get_script():
			script_name = (node.get_script() as Script).resource_path.get_file()
		var mass_str := ""
		if node is RigidBody3D:
			mass_str = " mass=%s" % (node as RigidBody3D).mass
		print("OK ", scene_path.get_file(), " type=", node.get_class(), " script=", script_name, mass_str)
		node.free()
	if failures == 0:
		print("ALL SCENES LOADED CLEAN")
	else:
		printerr("FAILURES: ", failures)
	quit(failures)
