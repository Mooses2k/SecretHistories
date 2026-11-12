extends GutTest

## Pins issue #651 (debug spawn box in the start-game cheat menu). The menu's
## existing spawn entries are Equipment/Tiny Items count settings consumed by
## the initial-settings-items generation step; the spawn box registers the
## typed path through the same settings pattern so generation spawns it on
## the first dungeon level like every counted entry. Pins:
## 1. An item scene path registers an Equipment-group spawn setting with the
##    full_path meta the generation step reads.
## 2. Pressing the same path again bumps the count.
## 3. A registered tiny item data path registers under the Tiny Items group.
## 4. Empty, non-res, unloadable, and non-item paths are rejected.
## 5. The menu scene carries the hidden spawn box wired to the handler,
##    sitting at the TOP of the tabbed cheat area (owner ruling 2026-11-09).

const SETTINGS_SCRIPT := "res://scenes/ui/start_game_settings.gd"
const MENU_SCENE := "res://scenes/ui/start_game_menu.tscn"
const ITEM_SCENE_PATH := "res://scenes/objects/pickable_items/_pickable_item.tscn"

var _saved_game : Game


func before_each() -> void:
	_saved_game = GameManager.game
	GameManager.game = null


func after_each() -> void:
	GameManager.game = _saved_game


func _boot_settings() -> Node:
	var settings_node : Node = (load(SETTINGS_SCRIPT) as GDScript).new()
	var settings : SettingsClass = SettingsClass.new()
	add_child_autofree(settings_node)
	add_child_autofree(settings)
	settings_node.attach_settings(settings)
	return settings_node


func test_item_scene_path_registers_an_equipment_spawn_setting() -> void:
	var settings_node := _boot_settings()
	var settings : SettingsClass = settings_node._settings

	assert_true(settings_node.register_spawn_by_path(ITEM_SCENE_PATH),
			"a valid item scene path registers")
	assert_true(settings.has_setting(ITEM_SCENE_PATH), "the path becomes a spawn setting")
	assert_eq(settings.get_setting_group(ITEM_SCENE_PATH), "Equipment",
			"item scenes register in the Equipment group the generation step reads")
	assert_eq(settings.get_setting(ITEM_SCENE_PATH), 1, "one spawn per press")
	assert_eq(settings.get_setting_meta(ITEM_SCENE_PATH, "full_path"), ITEM_SCENE_PATH,
			"the full path meta is what the generation step loads")


func test_pressing_the_same_path_again_spawns_one_more() -> void:
	var settings_node := _boot_settings()
	var settings : SettingsClass = settings_node._settings

	settings_node.register_spawn_by_path(ITEM_SCENE_PATH)
	settings_node.register_spawn_by_path(ITEM_SCENE_PATH)

	assert_eq(settings.get_setting(ITEM_SCENE_PATH), 2, "the second press bumps the count")


func test_tiny_item_path_registers_in_the_tiny_items_group() -> void:
	var paths_resource : ItemPathsResource = load("res://resources/item_paths.tres")
	var tiny_path : String = paths_resource.tiny_item_paths[0]
	var settings_node := _boot_settings()
	var settings : SettingsClass = settings_node._settings

	assert_true(settings_node.register_spawn_by_path(tiny_path),
			"a registered tiny item data path registers")

	assert_eq(settings.get_setting_group(tiny_path), "Tiny Items",
			"tiny item data registers in the Tiny Items group")
	assert_eq(settings.get_setting_meta(tiny_path, "full_path"), tiny_path,
			"the tiny item data path is the generation step's item_data_path")


func test_invalid_paths_are_rejected_without_registering() -> void:
	var settings_node := _boot_settings()
	var settings : SettingsClass = settings_node._settings
	var baseline : int = settings.get_settings_list().size()

	var rejected : bool = false
	rejected = rejected or settings_node.register_spawn_by_path("")
	rejected = rejected or settings_node.register_spawn_by_path("scenes/foo.tscn")
	rejected = rejected or settings_node.register_spawn_by_path("res://no/such/item.tscn")
	rejected = rejected or settings_node.register_spawn_by_path("res://resources/item_paths.tres")
	assert_false(rejected, "every invalid path is rejected")

	assert_eq(settings.get_settings_list().size(), baseline,
			"no setting was registered by the rejected paths")


func test_the_menu_scene_carries_the_hidden_spawn_box() -> void:
	# Text-level scene assertions: instantiating the menu scene would boot the
	# screen filter's shader init, which the dummy renderer cannot do. The
	# wiring is data, so the scene text is the truth here.
	var scene_text : String = FileAccess.get_file_as_string(MENU_SCENE)
	var lines : PackedStringArray = scene_text.split("\n")
	var box_line : int = -1
	for i in lines.size():
		if lines[i].begins_with("[node name=\"SpawnItemBox\" type=\"VBoxContainer\""):
			box_line = i
			break
	assert_true(box_line >= 0, "the spawn box node exists in the menu scene")
	if box_line >= 0:
		var block : String = ""
		for j in range(box_line, mini(box_line + 6, lines.size())):
			block += lines[j] + "\n"
		assert_true(block.contains("visible = false"), "the spawn box starts hidden")
		assert_true(block.contains("unique_name_in_owner = true"), "the spawn box is %unique addressed")
		assert_true(block.contains("parent=\"MarginContainer/HBoxContainer/ScrollContainer/CheatArea\""),
				"the spawn box lives inside the tabbed cheat area, not beside the menu buttons")
	assert_true(scene_text.contains("placeholder_text = \"res:// path to item scene or tiny item\""),
			"the path LineEdit explains what to type")
	assert_true(scene_text.contains("[node name=\"SpawnItemButton\" type=\"Button\" parent=\"MarginContainer/HBoxContainer/ScrollContainer/CheatArea/SpawnItemBox\"]"),
			"the spawn button lives in the spawn box")
	assert_true(scene_text.contains("[connection signal=\"pressed\" from=\"MarginContainer/HBoxContainer/ScrollContainer/CheatArea/SpawnItemBox/SpawnItemButton\" to=\".\" method=\"_on_SpawnItemButton_pressed\"]"),
			"the button press routes to the spawn handler")


func test_the_spawn_box_sits_at_the_top_of_the_cheat_tab_area() -> void:
	# Owner ruling 2026-11-09: the spawn box belongs at the TOP of the tabbed
	# cheat area, one instance above the cheat tabs, or nowhere.
	var scene_text : String = FileAccess.get_file_as_string(MENU_SCENE)
	var box_index : int = scene_text.find("[node name=\"SpawnItemBox\"")
	var cheat_area_index : int = scene_text.find("[node name=\"CheatArea\"")
	var settings_index : int = scene_text.find("[node name=\"AdaptiveSettingsUI\"")
	assert_true(cheat_area_index >= 0, "the cheat area wrapper exists inside the cheat scroll")
	assert_true(box_index >= 0 and settings_index >= 0, "precondition: both nodes exist")
	assert_true(box_index < settings_index,
			"the spawn box is declared before the cheat settings UI: first child, top of the area")
	assert_false(scene_text.contains("Column4/SpawnItemBox"),
			"no spawn box remains under Column4")

