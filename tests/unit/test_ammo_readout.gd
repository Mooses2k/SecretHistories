extends GutTest

## Tests for the hotbar ammo readout (issue #661): the qualitative word
## mapping, the inventory awareness set, and the readout rebuild listing
## encountered ammo types with their words. Nodes stay out of the tree so
## the production _ready (which needs the live game) never runs.

const AmmoReadoutScript = preload("res://scenes/ui/hotbar/ammo_readout.gd")
const InventoryScript = preload("res://scenes/characters/inventory.gd")
const WebleyAmmo = preload("res://resources/tiny_items/ammunition/455_webley.tres")
const ShotgunAmmo = preload("res://resources/tiny_items/ammunition/shotgun_shell.tres")


func _make_readout(inv: Inventory) -> VBoxContainer:
	var readout: VBoxContainer = VBoxContainer.new()
	readout.set_script(AmmoReadoutScript)
	readout.inventory = inv
	autofree(readout)
	return readout


func _labels(readout: VBoxContainer) -> Array[String]:
	var texts: Array[String] = []
	for child in readout.get_children():
		var label := child as Label
		if label != null:
			texts.append(label.text)
	return texts


func test_word_mapping_boundaries() -> void:
	assert_eq(AmmoReadoutScript.amount_word(0), "None")
	assert_eq(AmmoReadoutScript.amount_word(1), "Few")
	assert_eq(AmmoReadoutScript.amount_word(5), "Few")
	assert_eq(AmmoReadoutScript.amount_word(6), "Some")
	assert_eq(AmmoReadoutScript.amount_word(19), "Some")
	assert_eq(AmmoReadoutScript.amount_word(20), "Lots")
	assert_eq(AmmoReadoutScript.amount_word(500), "Lots")


func test_insert_marks_item_known_even_after_spending_to_zero() -> void:
	var inv: Inventory = autofree(InventoryScript.new())
	inv.hotbar.resize(Inventory.HOTBAR_SIZE)
	inv.insert_tiny_item(WebleyAmmo, 3)
	assert_true(inv.known_tiny_items.has(WebleyAmmo))
	assert_true(inv.remove_tiny_item(WebleyAmmo, 3))
	assert_false(inv.tiny_items.has(WebleyAmmo))
	assert_true(inv.known_tiny_items.has(WebleyAmmo))


func test_rebuild_lists_encountered_ammo_types_with_words() -> void:
	var inv: Inventory = autofree(InventoryScript.new())
	inv.hotbar.resize(Inventory.HOTBAR_SIZE)
	inv.tiny_items = {WebleyAmmo: 2}
	inv.known_tiny_items = {WebleyAmmo: true}
	var readout := _make_readout(inv)
	readout.call("_rebuild")
	assert_eq(_labels(readout), [".455 Webley round: Few"] as Array[String])


func test_rebuild_shows_none_when_known_type_hits_zero() -> void:
	var inv: Inventory = autofree(InventoryScript.new())
	inv.hotbar.resize(Inventory.HOTBAR_SIZE)
	inv.tiny_items = {}
	inv.known_tiny_items = {ShotgunAmmo: true}
	var readout := _make_readout(inv)
	readout.call("_rebuild")
	assert_eq(_labels(readout), ["shotgun shell: None"] as Array[String])


func test_hotbar_scene_carries_the_readout_node() -> void:
	var scene: PackedScene = load("res://scenes/ui/hotbar/hotbar.tscn")
	assert_not_null(scene)
	var root: Node = (scene as PackedScene).instantiate()
	autofree(root)
	var readout: Node = root.get_node_or_null("VBoxContainer/AmmoReadout")
	assert_not_null(readout)
	var script: Script = readout.get_script() as Script
	assert_not_null(script)
	assert_eq(script.resource_path, "res://scenes/ui/hotbar/ammo_readout.gd")
	# The hand-edited scene must keep every pre-existing slot intact
	var slot10: Node = root.get_node_or_null("VBoxContainer/10")
	assert_not_null(slot10)
	assert_not_null(slot10.get_script())
	assert_eq(root.get_node("VBoxContainer").get_child_count(), 13)
