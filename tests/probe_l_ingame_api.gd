extends SceneTree

## One-off API probe for the L screen-filter fix lane. Answers with prints,
## then quits: (1) the engine default effect_callback_type of a bare
## CompositorEffect, (2) whether Compositor + WorldEnvironment.compositor
## assignment works without a renderer, (3) what instantiating the real
## game.tscn does headless around the pre-seeded color reduce effect.

func _init() -> void:
	var iter := 0
	while Engine.get_main_loop() == null and iter < 40:
		await create_timer(0.05).timeout
		iter += 1

	var bare := CompositorEffect.new()
	print("PROBE default effect_callback_type=", bare.effect_callback_type)
	print("PROBE POST_TRANSPARENT=", CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT)
	print("PROBE PRE_OPAQUE=", CompositorEffect.EFFECT_CALLBACK_TYPE_PRE_OPAQUE)
	print("PROBE enabled=", bare.enabled)

	var comp := Compositor.new()
	print("PROBE compositor_effects_default=", comp.compositor_effects)

	var we := WorldEnvironment.new()
	we.compositor = comp
	print("PROBE we.compositor_roundtrip=", we.compositor == comp)

	# The real game scene, headless: watch for the color reduce _init error.
	var game_scene : PackedScene = load("res://scenes/game.tscn")
	print("PROBE game_scene=", game_scene != null)
	var game : Node = game_scene.instantiate()
	print("PROBE game_instantiated=", game != null)
	var filters : Node = game.get_node("ScreenFilters") if game.get_node_or_null("ScreenFilters") != null else null
	print("PROBE filters_node=", filters != null)
	if filters != null:
		print("PROBE filters_script=", filters.get_script().resource_path)
	root.add_child(game)
	print("PROBE game_added_to_tree")
	await create_timer(0.5).timeout
	if filters != null:
		var we_node = filters.get("world_environment")
		print("PROBE filters_world_environment=", we_node)
		if we_node != null:
			print("PROBE filters_we_compositor=", we_node.compositor != null)
		var effects = filters.get("_compositor_effects")
		print("PROBE seeded_effect_count=", effects.size() if effects != null else -1)
		if effects != null and effects.size() > 0:
			var seeded = effects[0]
			print("PROBE seeded_callback_type=", seeded.effect_callback_type,
					" enabled=", seeded.enabled,
					" shader_valid=", seeded.shader.is_valid())
	quit(0)
