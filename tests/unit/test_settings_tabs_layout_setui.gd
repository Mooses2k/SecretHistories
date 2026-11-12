extends GutTest

## Pins the settings tab reflow (owner playtest feedback, 2026-11-09):
## 1. The Gunplay group renders sectioned INSIDE the Game tab, never as a
##    tab of its own, with both of its rows functioning.
## 2. The settings window width is back at the pre-widening 1.2 aspect cap
##    (the gamepad tab won over the widened window).
## 3. Every tab carries exactly ONE Reset button: on the binding tabs it
##    rides the first binding row to the right of Change and Clear/Defaults
##    and opens the landed confirmation panel; on the other tabs it is a
##    compact right-aligned row at the top that resets that tab's rows.
##    The old repeated long-named reset rows are gone.
## The real settings_menu.tscn is instantiated; rows build through the real
## attach_settings flow against the live Settings autoload.

const SETTINGS_MENU_SCENE := "res://scenes/ui/settings_menu.tscn"

var menu : Control


func before_each() -> void:
	menu = (load(SETTINGS_MENU_SCENE) as PackedScene).instantiate()
	add_child_autofree(menu)
	menu.visible = true


func _tab_buttons() -> PackedStringArray:
	var names := PackedStringArray()
	var buttons : Node = menu.find_child("TabButtons", true, false)
	for button in buttons.get_children():
		names.append((button as Button).text)
	return names


func _tab_content(tab_name : String) -> Control:
	return menu.find_child("TabContent_" + tab_name, true, false) as Control


func _group_blocks(root : Node) -> Array:
	var blocks : Array = []
	var stack : Array[Node] = [root]
	while not stack.is_empty():
		var node : Node = stack.pop_back()
		if node.has_method("get_group_name"):
			blocks.append(node)
		stack.append_array(node.get_children())
	return blocks


func _reset_buttons(root : Node) -> Array:
	var buttons : Array = []
	var stack : Array[Node] = [root]
	while not stack.is_empty():
		var node : Node = stack.pop_back()
		if node is Button and (node as Button).name == "ResetButton":
			buttons.append(node)
		stack.append_array(node.get_children())
	return buttons


func test_gunplay_is_sectioned_inside_the_game_tab() -> void:
	var tabs := _tab_buttons()
	assert_eq(tabs, PackedStringArray(["Video", "Audio", "Game", "Input", "Gamepad"]),
			"the tab strip has no Gunplay tab")
	var game_tab := _tab_content("Game")
	assert_not_null(game_tab, "the Game tab exists")
	var group_names := PackedStringArray()
	for block in _group_blocks(game_tab):
		group_names.append(str(block.call("get_group_name")).strip_edges())
	assert_true(group_names.has("Game Settings"), "the Game tab keeps its own group")
	assert_true(group_names.has("Gunplay"),
			"the Gunplay group renders as a titled section inside the Game tab")


func test_gunplay_rows_keep_working_inside_the_game_tab() -> void:
	var game_tab := _tab_content("Game")
	for block in _group_blocks(game_tab):
		if str(block.call("get_group_name")).strip_edges() != "Gunplay":
			continue
		var list : Node = block.get_node("ListOffset/SettingsList")
		assert_eq(list.get_child_count(), 2, "both Gunplay rows render inside the Game tab")
		var shell_row : Node = list.get_child(0)
		var slider_row : Node = list.get_child(1)
		assert_eq((shell_row.get_node("%Name") as Label).text, "Realistic Shell Ejection")
		assert_eq((slider_row.get_node("%Name") as Label).text, "Ironsight Aim Sensitivity")
		return
	assert_false(true, "the Gunplay group block was not found in the Game tab")


func test_settings_window_width_is_reverted() -> void:
	var container : Node = menu.find_child("MaxAspectContainer", true, false)
	assert_eq(container.get("max_aspect_ratio"), 1.2,
			"the settings panel caps at the pre-widening 1.2 aspect ratio")


func test_every_tab_carries_exactly_one_reset_button() -> void:
	for tab_name in ["Video", "Audio", "Game", "Input", "Gamepad"]:
		var tab := _tab_content(tab_name)
		assert_not_null(tab, "the %s tab exists" % tab_name)
		assert_eq(_reset_buttons(tab).size(), 1,
				"the %s tab carries exactly one Reset button" % tab_name)


func test_binding_tabs_ride_the_reset_in_the_change_clear_row() -> void:
	for tab_name in ["Input", "Gamepad"]:
		var reset : Button = _reset_buttons(_tab_content(tab_name))[0]
		var row : Node = reset.get_parent()
		var row_texts := PackedStringArray()
		for child in row.get_children():
			if child is Button:
				row_texts.append((child as Button).text)
		assert_true(row_texts.has("Change"),
				"the %s tab Reset shares the row with Change" % tab_name)
		assert_true(row_texts.has("Clear") or row_texts.has("Defaults"),
				"the %s tab Reset shares the row with Clear/Defaults" % tab_name)
		assert_gt(reset.get_index(), 0, "the Reset sits to the RIGHT of Change and Clear")
		assert_gt(reset.get_signal_connection_list("pressed").size(), 0,
				"the %s tab Reset is connected (no silent no-op)" % tab_name)
		var index_in_parent := row.get_children().find(reset)
		assert_eq(index_in_parent, row.get_child_count() - 1,
				"the Reset is the rightmost control of the row")


func test_plain_tabs_carry_a_right_aligned_reset_row_on_top() -> void:
	for tab_name in ["Video", "Audio", "Game"]:
		var reset : Button = _reset_buttons(_tab_content(tab_name))[0]
		var row : HBoxContainer = reset.get_parent() as HBoxContainer
		assert_eq(row.name, "TabResetRow", "the %s tab reset is its own compact row" % tab_name)
		assert_eq(row.alignment, BoxContainer.ALIGNMENT_END,
				"the %s tab reset row is right-aligned" % tab_name)
		assert_eq(row.get_index(), 0, "the %s tab reset row sits at the top of the tab" % tab_name)


func test_the_old_long_named_reset_rows_are_gone() -> void:
	var stack : Array[Node] = [menu]
	while not stack.is_empty():
		var node : Node = stack.pop_back()
		if node is Button:
			assert_false(str((node as Button).text).strip_edges() == "Reset to defaults",
					"no long-named reset row remains")
		stack.append_array(node.get_children())


func test_game_tab_reset_restores_its_rows_including_gunplay() -> void:
	Settings.set_setting("Auto-switch weapons on throw", 2)
	Settings.set_setting("Realistic Shell Ejection", true)
	Settings.set_setting("Ironsight Aim Sensitivity", 0.05)

	var reset : Button = _reset_buttons(_tab_content("Game"))[0]
	reset.pressed.emit()

	assert_eq(Settings.get_setting("Auto-switch weapons on throw"), 0,
			"the Game row is back to its default")
	assert_eq(Settings.get_setting("Realistic Shell Ejection"), false,
			"the Gunplay bool row is back to its default")
	assert_eq(Settings.get_setting("Ironsight Aim Sensitivity"), 0.8,
			"the Gunplay slider row is back to its default")
