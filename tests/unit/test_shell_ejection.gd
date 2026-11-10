extends GutTest
## Shell ejection on reload (3.x behavior restored, code-driven): a reload
## press opens the action and ejects the chambers' contents as world physics
## debris via the gun's per-gun shell effect node, at the swing-open
## beat (owner decision: swing out and empty, then load one round per
## cycle). The "Realistic Shell Ejection" setting picks the mode, read at
## press time: OFF (default, arcade) ejects only the chambers holding spent
## cases (ammunition_capacity - current_ammo); ON (realistic) empties every
## chamber like an ejector rod run, the spent chambers leaving casings and
## each unfired round landing in the world as its loose-ammo pickup item
## (total ejected items = capacity; unspent rounds are never returned to
## inventory by an ejection). The ready-time convenience load ("start
## loaded, for now") ejects nothing in either mode.
## 3.x shape reference (Ayo's late commits): webley ejects 6 casings, both
## shotguns 2 shells, khyber 1, all into the world; Lee-Metford and
## Martini-Henry rifle never ejected.
##
## Harness: real webley scene (its ShellReloadEffects node and chamber
## markers come from the scene) with a stub owner carrying a real state and
## Inventory, the same pattern as test_reload_stage_abort. Seam assertions
## use a recording double swapped onto gun_item._shell_effects; the real
## spawn path runs against a throwaway parent node. Casings and loose-round
## pickups are both TinyItem scenes; the pickups carry the ammo item_data
## and the casings leave it null.

const InventoryScript = preload("res://scenes/characters/inventory.gd")
const WebleyScene = preload("res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn")
const DoubleBarrelScene = preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_shotgun/double-barrel_shotgun.tscn")
const KhyberScene = preload("res://scenes/objects/pickable_items/equipment/ranged/khyber_pass_martini/khyber_pass_martini.tscn")
const GameScript = preload("res://scenes/game.gd")
const AmmoResource = preload("res://resources/tiny_items/ammunition/455_webley.tres")
const StateScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_state.gd")
const ParametersScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_parameters.gd")
const InputScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character_input.gd")


class ReloadOwnerStub extends Node:
	var state = null
	var inventory = null


class ShellEffectsDouble extends Node:
	var calls : Array = []
	var pickup_calls : Array = []

	func expell_shells(count : int, world_parent : Node) -> void:
		calls.append({"count": count, "parent": world_parent})

	func expell_live_rounds(count : int, world_parent : Node) -> void:
		pickup_calls.append({"count": count, "parent": world_parent})


func _make_harness(start_ammo : int, start_tiny : int, stage_amount : int = 6, stub_clip_length : float = 0.6, ready_loaded : bool = false, capacity : int = 6) -> Dictionary:
	var owner_stub : ReloadOwnerStub = ReloadOwnerStub.new()
	add_child_autofree(owner_stub)
	var params : Node = ParametersScript.new()
	params.name = "Parameters"
	var input_node : Node = InputScript.new()
	input_node.name = "Input"
	var state : Node = StateScript.new()
	state.name = "State"
	owner_stub.add_child(params)
	owner_stub.add_child(input_node)
	owner_stub.add_child(state)
	state.owner = owner_stub
	owner_stub.state = state

	var inv = add_child_autofree(InventoryScript.new())
	owner_stub.inventory = inv

	var webley = WebleyScene.instantiate()
	webley.ammunition_capacity = capacity
	webley.reload_amount = stage_amount
	webley.reload_time = 0.25
	if ready_loaded:
		# Set up before add_child so _ready runs the convenience load; the
		# clip stub cannot be applied here (animation_player needs the tree).
		webley.owner_character = owner_stub
		webley.current_ammo_type = AmmoResource
		webley.current_ammo = start_ammo
		inv.tiny_items[AmmoResource] = start_tiny
		add_child_autofree(webley)
	else:
		add_child_autofree(webley)
		webley.owner_character = owner_stub
		webley.current_ammo_type = AmmoResource
		webley.current_ammo = start_ammo
		inv.tiny_items[AmmoResource] = start_tiny
		if stub_clip_length >= 0.0:
			_own_reload_library(webley, stub_clip_length)
	# _ready's get_reload_length() derives the composite value from the real
	# 8.067 s clip; pin the 0.25 fallback back for the tests that ride
	# reload_time directly (the unload boundary starts from it).
	webley.reload_time = 0.25
	return {"owner": owner_stub, "state": state, "inventory": inv, "webley": webley}


func _own_reload_library(webley : Node, stub_clip_length : float) -> void:
	# The scene's sub_resource AnimationLibrary is shared across instantiate()
	# calls, so the stub goes into a private per-instance copy.
	var anim_player : AnimationPlayer = webley.animation_player
	var shared : AnimationLibrary = anim_player.get_animation_library("")
	var private_lib := AnimationLibrary.new()
	for anim_name in shared.get_animation_list():
		if stub_clip_length == 0.0 and anim_name == "reload":
			continue
		private_lib.add_animation(anim_name, shared.get_animation(anim_name))
	if stub_clip_length > 0.0:
		private_lib.remove_animation("reload")
		var stub_anim := Animation.new()
		stub_anim.length = stub_clip_length
		private_lib.add_animation("reload", stub_anim)
	anim_player.remove_animation_library("")
	anim_player.add_animation_library("", private_lib)


func _swap_double(webley : Node) -> ShellEffectsDouble:
	var effects := ShellEffectsDouble.new()
	autofree(effects)
	webley._shell_effects = effects
	return effects


func _set_realistic(enabled : bool) -> void:
	GameSettings.set_realistic_shell_ejection(enabled)


func after_each() -> void:
	# The Settings registry is global across the suite: every realistic-mode
	# test must leave the OFF default behind.
	_set_realistic(false)


func test_webley_press_ejects_all_spent_casings_at_the_press() -> void:
	var h := _make_harness(0, 6, 6)
	var webley : Node = h.webley
	var effects := _swap_double(webley)

	webley.reload()
	assert_eq(effects.calls.size(), 1, "the press ejects once, at the swing-open beat")
	if effects.calls.size() == 1:
		assert_eq(effects.calls[0]["count"], 6, "an empty cylinder ejects all six spent cases")
	webley.request_reload_abort()


func test_partial_cylinder_ejects_only_the_spent_cases() -> void:
	var h := _make_harness(4, 6, 6)
	var webley : Node = h.webley
	var effects := _swap_double(webley)

	webley.reload()
	assert_eq(effects.calls.size(), 1, "the press ejects once")
	if effects.calls.size() == 1:
		assert_eq(effects.calls[0]["count"], 2, "two live rounds in the cylinder means two spent cases")
	webley.request_reload_abort()


func test_full_weapon_refuses_and_ejects_nothing() -> void:
	var h := _make_harness(6, 6, 6)
	var webley : Node = h.webley
	var effects := _swap_double(webley)

	webley.reload()
	assert_false(h.state.is_reloading, "a full weapon must not enter a reload stage")
	assert_eq(effects.calls.size(), 0, "a refused reload ejects nothing")


func test_ready_time_spawn_load_does_not_eject() -> void:
	# _ready self-loads the gun ("start loaded, for now"); that convenience
	# load is not a press and the chamber never held spent cases.
	var fake_game : Node = GameScript.new()
	autofree(fake_game)
	GameManager.game = fake_game
	var h := _make_harness(0, 6, 6, 0.6, true)
	GameManager.game = null
	assert_true(h.state.is_reloading, "the ready-time load stages the weapon")
	assert_eq(fake_game.get_child_count(), 0, "the ready-time load ejects nothing")
	h.webley.request_reload_abort()


func test_abort_mid_chain_ejects_nothing_further_and_a_re_press_ejects_the_remaining_spent() -> void:
	var h := _make_harness(0, 6, 6)
	var webley : Node = h.webley
	var effects := _swap_double(webley)

	webley.reload()
	assert_eq(effects.calls.size(), 1, "the first press ejects at the swing-open beat")
	await wait_seconds(0.4)
	assert_eq(webley.current_ammo, 1, "round one landed before the abort")

	webley.request_reload_abort()
	assert_eq(effects.calls.size(), 1, "the abort itself ejects nothing")

	webley.reload()
	assert_eq(effects.calls.size(), 2, "the re-press opens the action again")
	if effects.calls.size() == 2:
		assert_eq(effects.calls[0]["count"], 6, "the first press ejected the empty cylinder")
		assert_eq(effects.calls[1]["count"], 5, "the re-press ejects the chambers still without a live round")
	webley.request_reload_abort()


func test_casings_land_in_the_world_parent_as_physics_debris() -> void:
	# The gun hands _casing_world_parent() to the effects node; in a real run
	# that is GameManager.game, falling back to the current scene. The test
	# provides the fallback branch as an in-tree container so the casings
	# spawn through the same production path.
	var h := _make_harness(0, 6, 6)
	var webley : Node = h.webley
	var world_container := Node3D.new()
	autofree(world_container)
	# current_scene must be a direct child of the tree root.
	get_tree().root.add_child(world_container)
	get_tree().current_scene = world_container
	webley.reload()
	get_tree().current_scene = null
	assert_eq(world_container.get_child_count(), 6, "the press ejects six casings into the world parent")
	for casing in world_container.get_children():
		assert_true(casing is RigidBody3D, "casings spawn as world physics debris")
	webley.request_reload_abort()


func test_webley_effects_spawn_casings_at_the_chamber_markers() -> void:
	var h := _make_harness(0, 6, 6)
	var webley : Node = h.webley
	var effects : Node = webley._shell_effects
	assert_true(effects != null, "the webley scene wires AnimationPlayer/ShellReloadEffects")

	var container := Node3D.new()
	add_child_autofree(container)
	effects.expell_shells(6, container)
	assert_eq(container.get_child_count(), 6, "the webley spawns one casing per chamber marker")
	for casing in container.get_children():
		assert_true(casing is RigidBody3D, "casings are RigidBody3D debris")
	var marker : Node3D = webley.get_node("Webley/Webley_Arm/Skeleton3D/Webley2/BulletPosition")
	var first_casing : Node3D = container.get_child(0)
	assert_almost_eq(first_casing.global_position.y, marker.global_position.y + 0.05, 0.001, "the casing starts at the chamber position plus the lift")

	var before : int = container.get_child_count()
	effects.expell_shells(9, container)
	assert_eq(container.get_child_count() - before, 6, "the eject count clamps to the six chamber markers")


func test_shotgun_effects_spawn_two_shells_and_clamp_to_their_markers() -> void:
	var gun := DoubleBarrelScene.instantiate()
	add_child_autofree(gun)
	var effects : Node = gun._shell_effects
	assert_true(effects != null, "the double-barrel scene wires AnimationPlayer/ShellReloadEffects")

	var container := Node3D.new()
	add_child_autofree(container)
	effects.expell_shells(2, container)
	assert_eq(container.get_child_count(), 2, "the double-barrel ejects both spent shells")
	for casing in container.get_children():
		assert_true(casing is RigidBody3D, "shells are RigidBody3D debris")
	var before : int = container.get_child_count()
	effects.expell_shells(7, container)
	assert_eq(container.get_child_count() - before, 2, "the eject count clamps to the two breech markers")


func test_khyber_effects_spawn_one_casing() -> void:
	var gun := KhyberScene.instantiate()
	add_child_autofree(gun)
	var effects : Node = gun._shell_effects
	assert_true(effects != null, "the khyber scene wires AnimationPlayer/KyberPassMartiniShells")

	var container := Node3D.new()
	add_child_autofree(container)
	effects.expell_shells(1, container)
	assert_eq(container.get_child_count(), 1, "the khyber ejects its single spent case")
	var before : int = container.get_child_count()
	effects.expell_shells(3, container)
	assert_eq(container.get_child_count() - before, 1, "the eject count clamps to the single marker")
	var casing : Node = container.get_child(0)
	assert_true(casing is RigidBody3D, "the casing is RigidBody3D debris")


func test_guns_without_shell_wiring_reload_silently() -> void:
	# Lee-Metford and Martini-Henry rifle carry no shell_effects_path in 3.x
	# or dev4: the reload works and nothing ejects.
	var h := _make_harness(0, 6, 6)
	var webley : Node = h.webley
	webley._shell_effects = null
	webley.reload()
	assert_true(h.state.is_reloading, "the staged reload starts without a shell effect node")
	webley.request_reload_abort()
	assert_false(h.state.is_reloading, "the abort still clears the reload state")


func test_realistic_empty_cylinder_ejects_capacity_casings_and_no_pickups() -> void:
	# An all-spent cylinder is the common press: every chamber leaves its
	# casing and there is no unfired round to become a pickup. Same casing
	# count as arcade mode; the mode differs only with live rounds chambered.
	_set_realistic(true)
	var h := _make_harness(0, 6, 6)
	var webley : Node = h.webley
	var effects := _swap_double(webley)

	webley.reload()
	assert_eq(effects.calls.size(), 1, "the press ejects the spent cases once")
	if effects.calls.size() == 1:
		assert_eq(effects.calls[0]["count"], 6, "an empty cylinder ejects all six casings")
	assert_eq(effects.pickup_calls.size(), 0, "an empty cylinder has no unfired rounds to eject")
	webley.request_reload_abort()


func test_realistic_partial_cylinder_spent_casings_plus_live_pickups() -> void:
	# Four live rounds, two spent: the ejector rod run empties all chambers,
	# two casings plus four loose pickups, six ejected items for six chambers.
	_set_realistic(true)
	var h := _make_harness(4, 6, 6)
	var webley : Node = h.webley
	var effects := _swap_double(webley)

	webley.reload()
	assert_eq(effects.calls.size(), 1, "the spent chambers eject their casings once")
	if effects.calls.size() == 1:
		assert_eq(effects.calls[0]["count"], 2, "two spent chambers leave two casings")
	assert_eq(effects.pickup_calls.size(), 1, "the unfired rounds eject as loose pickups")
	if effects.pickup_calls.size() == 1:
		assert_eq(effects.pickup_calls[0]["count"], 4, "four live rounds land as pickups")
	webley.request_reload_abort()


func test_realistic_two_round_gun_ejects_capacity_items_total() -> void:
	# The owner's example: a two-round gun holding one live round and one
	# spent case ejects one casing and one live cartridge, two ejected items
	# for two chambers. No phantom casing for the unfired round.
	_set_realistic(true)
	var h := _make_harness(1, 6, 6, 0.6, false, 2)
	var webley : Node = h.webley
	var effects := _swap_double(webley)

	webley.reload()
	assert_eq(effects.calls.size(), 1, "the spent chamber ejects its casing once")
	if effects.calls.size() == 1:
		assert_eq(effects.calls[0]["count"], 1, "one spent chamber leaves one casing")
	assert_eq(effects.pickup_calls.size(), 1, "the unfired round ejects as a loose pickup")
	if effects.pickup_calls.size() == 1:
		assert_eq(effects.pickup_calls[0]["count"], 1, "one live round lands as a pickup")
	webley.request_reload_abort()


func test_setting_change_at_runtime_applies_from_the_next_press() -> void:
	# The setting is read at press time: an OFF press then an ON press on the
	# same gun session must switch the ejection behavior immediately.
	var h := _make_harness(0, 6, 6)
	var webley : Node = h.webley
	var effects := _swap_double(webley)

	webley.reload()
	assert_eq(effects.calls.size(), 1, "the arcade press ejects the spent cases")
	assert_eq(effects.pickup_calls.size(), 0, "arcade mode ejects no pickups")
	await wait_seconds(0.4)
	assert_eq(webley.current_ammo, 1, "round one landed before the abort")
	webley.request_reload_abort()
	assert_eq(webley.current_ammo, 1, "the abort keeps the landed round")

	_set_realistic(true)
	webley.reload()
	assert_eq(effects.calls.size(), 2, "the re-press still ejects the spent casings")
	if effects.calls.size() == 2:
		assert_eq(effects.calls[1]["count"], 5, "five spent chambers leave five casings")
	assert_eq(effects.pickup_calls.size(), 1, "the realistic re-press now ejects pickups too")
	if effects.pickup_calls.size() == 1:
		assert_eq(effects.pickup_calls[0]["count"], 1, "the one chambered live round lands as a pickup")
	webley.request_reload_abort()


func test_realistic_press_spawns_loose_round_pickups_through_the_world_parent() -> void:
	# The real spawn path: two casings plus four pickup TinyItems, all through
	# the same world-parent fallback the casings use. A pickup is the gun's
	# ammo type's loose round scene carrying the .455 Webley item data; a
	# casing carries no item data.
	_set_realistic(true)
	var h := _make_harness(4, 6, 6)
	var webley : Node = h.webley
	var world_container := Node3D.new()
	autofree(world_container)
	get_tree().root.add_child(world_container)
	get_tree().current_scene = world_container
	webley.reload()
	get_tree().current_scene = null
	assert_eq(world_container.get_child_count(), 6, "six chambers, six ejected items: two casings plus four pickups")
	var pickups : Array = []
	for child in world_container.get_children():
		assert_true(child is RigidBody3D, "ejected items spawn as world physics bodies")
		if child.get("item_data") != null:
			pickups.append(child)
	assert_eq(pickups.size(), 4, "the four unfired rounds land as loose pickup items")
	for pickup in pickups:
		assert_eq(pickup.get("item_data"), AmmoResource, "each pickup carries the webley ammo item data")
		assert_eq(pickup.get("amount"), 1, "each pickup is one round")
	webley.request_reload_abort()


func test_realistic_unload_press_ejects_and_keeps_the_rounds_out_of_the_inventory() -> void:
	# The unload press opens the action too: the live rounds land in the
	# world as pickups and the unload boundary must not ALSO return them to
	# the inventory (they are in the world now, grabbable).
	_set_realistic(true)
	var h := _make_harness(6, 0)
	var webley : Node = h.webley
	var effects := _swap_double(webley)

	webley.unload()
	assert_eq(effects.calls.size(), 0, "a fully loaded cylinder holds no spent cases to eject")
	assert_eq(effects.pickup_calls.size(), 1, "the unload press ejects the live rounds as pickups")
	if effects.pickup_calls.size() == 1:
		assert_eq(effects.pickup_calls[0]["count"], 6, "all six live rounds land as pickups")

	await wait_seconds(0.6)

	assert_eq(webley.current_ammo, 0, "the unload still empties the weapon at its boundary")
	assert_eq(h.inventory.tiny_items[AmmoResource], 0, "the ejected live rounds stay in the world, not the inventory")
	assert_false(h.state.is_reloading, "the unload boundary still clears the reload state")


func test_arcade_unload_press_still_returns_rounds_to_the_inventory() -> void:
	# OFF mode unload is unchanged: no ejection, the quiet inventory return.
	var h := _make_harness(6, 0)
	var webley : Node = h.webley
	var effects := _swap_double(webley)

	webley.unload()
	assert_eq(effects.calls.size(), 0, "the arcade unload ejects nothing")
	assert_eq(effects.pickup_calls.size(), 0, "the arcade unload ejects no pickups")

	await wait_seconds(0.6)

	assert_eq(webley.current_ammo, 0, "the unload empties the weapon at its boundary")
	assert_eq(h.inventory.tiny_items[AmmoResource], 6, "the rounds return to the inventory in arcade mode")


func test_ready_time_spawn_load_stays_silent_in_realistic_mode() -> void:
	# The convenience load passes eject=false: even with realistic mode on,
	# the ready-time load is not a press and the chamber never held spent
	# cases or ejectable live rounds.
	_set_realistic(true)
	var fake_game : Node = GameScript.new()
	autofree(fake_game)
	GameManager.game = fake_game
	var h := _make_harness(0, 6, 6, 0.6, true)
	GameManager.game = null
	assert_true(h.state.is_reloading, "the ready-time load stages the weapon")
	assert_eq(fake_game.get_child_count(), 0, "the ready-time load ejects nothing in realistic mode either")
	h.webley.request_reload_abort()


func test_guns_without_shell_wiring_stay_silent_in_realistic_mode() -> void:
	# Lee-Metford and Martini-Henry rifle have no shell effects node: both
	# modes reload silently until their wiring lands.
	_set_realistic(true)
	var h := _make_harness(4, 6, 6)
	var webley : Node = h.webley
	webley._shell_effects = null
	webley.reload()
	assert_true(h.state.is_reloading, "the staged reload starts without a shell effect node")
	assert_eq(webley.current_ammo, 4, "the live rounds were not disturbed")
	webley.request_reload_abort()
	assert_false(h.state.is_reloading, "the abort still clears the reload state")
