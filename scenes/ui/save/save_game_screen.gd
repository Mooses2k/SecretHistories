extends Control

# Save/load slot picker. Behavior contract: set_mode("save"/"load"),
# 120 slots, 6 per page, 20 pages, page buttons in rows of 10, delete
# behind a confirm popup, slot manifests read only through
# SaveManager.read_slot_manifest, saves through SaveManager.save_to_slot,
# loads through SaveManager.begin_load + start_loaded_game.
#
# Chrome with no SH counterpart is re-styled here with plain Controls in
# SH's dark palette; the exhibition staging reduces to a tile grid plus a
# details card.

signal operation_completed(success: bool, message: String)

const SLOTS_PER_PAGE: int = 6
const TOTAL_PAGES: int = 20
const PAGE_BUTTONS_PER_ROW: int = 10

const COL_BG := Color(0.05, 0.05, 0.06)
const COL_PANEL := Color(0.10, 0.10, 0.12)
const COL_TEXT := Color(0.87, 0.85, 0.80)
const COL_MUTED := Color(0.55, 0.53, 0.50)
const COL_ACCENT := Color(0.72, 0.62, 0.42)
const COL_NEGATIVE := Color(0.78, 0.35, 0.30)
const COL_POSITIVE := Color(0.45, 0.70, 0.45)
const COL_CAUTION := Color(0.80, 0.65, 0.30)

var _mode: String = "load"
var _save_slots: Array = []
var _current_page: int = 0
var _selected_slot: int = 0

var _tiles: Dictionary = {}
var _subline: Label
var _detail: Label
var _action_btn: Button
var _delete_btn: Button
var _delete_popup: PopupPanel = null
var _delete_pending: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_scan_save_slots()
	_populate_tiles()
	_select_default_slot()


func set_mode(mode: String) -> void:
	_mode = mode
	if _subline != null:
		_update_subline()
	_fill_detail()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COL_BG
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	# Header: title, back button, subline.
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	var title: Label = Label.new()
	title.text = "Saves"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(title)
	var back_btn: Button = Button.new()
	back_btn.text = "back"
	back_btn.flat = true
	back_btn.add_theme_font_size_override("font_size", 15)
	back_btn.add_theme_color_override("font_color", COL_MUTED)
	back_btn.add_theme_color_override("font_hover_color", COL_TEXT)
	back_btn.pressed.connect(func() -> void: queue_free())
	row.add_child(back_btn)

	_subline = Label.new()
	_subline.add_theme_font_size_override("font_size", 14)
	_subline.add_theme_color_override("font_color", COL_MUTED)
	content.add_child(_subline)
	_update_subline()

	# Body: the six-slot page grid plus the details card.
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)

	var grid_scroll: ScrollContainer = ScrollContainer.new()
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(grid_scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.add_child(grid)
	for i in range(SLOTS_PER_PAGE):
		var slot_number: int = _current_page * SLOTS_PER_PAGE + i + 1
		var tile: Button = _build_tile(slot_number)
		_tiles[slot_number] = tile
		grid.add_child(tile)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	body.add_child(panel)
	var plaque: VBoxContainer = VBoxContainer.new()
	plaque.add_theme_constant_override("separation", 8)
	panel.add_child(plaque)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_font_size_override("font_size", 14)
	_detail.add_theme_color_override("font_color", COL_TEXT)
	plaque.add_child(_detail)
	_action_btn = Button.new()
	_action_btn.custom_minimum_size = Vector2(0, 40)
	_action_btn.pressed.connect(_on_action_pressed)
	plaque.add_child(_action_btn)
	_delete_btn = Button.new()
	_delete_btn.custom_minimum_size = Vector2(0, 32)
	_delete_btn.pressed.connect(_on_delete_pressed)
	plaque.add_child(_delete_btn)

	# Page buttons, rows of 10.
	var page_box: VBoxContainer = VBoxContainer.new()
	page_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	page_box.add_theme_constant_override("separation", 4)
	content.add_child(page_box)
	var current_row: HBoxContainer = null
	for p in range(TOTAL_PAGES):
		if p % PAGE_BUTTONS_PER_ROW == 0:
			current_row = HBoxContainer.new()
			current_row.alignment = BoxContainer.ALIGNMENT_CENTER
			current_row.add_theme_constant_override("separation", 4)
			page_box.add_child(current_row)
		var btn: Button = Button.new()
		btn.text = "%d" % (p + 1)
		btn.flat = true
		btn.custom_minimum_size = Vector2(36, 28)
		btn.pressed.connect(_on_page_button_pressed.bind(p))
		current_row.add_child(btn)
		btn.set_meta("page", p)
	_update_page_button_highlight()


func _build_tile(slot_number: int) -> Button:
	var tile: Button = Button.new()
	tile.custom_minimum_size = Vector2(220, 130)
	tile.add_theme_font_size_override("font_size", 13)
	tile.add_theme_color_override("font_color", COL_TEXT)
	tile.pressed.connect(_on_tile_pressed.bind(slot_number))
	return tile


func _style_tile(tile: Button, slot: Dictionary) -> void:
	# Screenshot thumb over a dark
	# panel: the background is drawn by painting the tile's stylebox and an
	# optional TextureRect child is avoided by using an icon.
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = COL_PANEL if bool(slot.get("exists", false)) else Color(0.07, 0.07, 0.08)
	box.border_color = COL_ACCENT if int(slot.get("slot_number", -1)) == _selected_slot else Color(0.2, 0.2, 0.22)
	box.set_border_width_all(2 if int(slot.get("slot_number", -1)) == _selected_slot else 1)
	box.set_content_margin_all(8)
	for state in ["normal", "hover", "pressed", "focus"]:
		tile.add_theme_stylebox_override(state, box)
	tile.icon = _load_thumb(slot)
	var shot_path: String = str(slot.get("screenshot_path", ""))
	tile.text = "PATH %03d" % int(slot.get("slot_number", 0)) if shot_path == "" else ""


func _load_thumb(slot: Dictionary) -> Texture2D:
	var shot_path: String = str(slot.get("screenshot_path", ""))
	if shot_path == "":
		return null
	var tex: ImageTexture = ImageTexture.create_from_image(Image.load_from_file(shot_path))
	return tex


### Slot scanning (the sanctioned manifest reader only) -----------------------------

func _scan_save_slots() -> void:
	_save_slots.clear()
	var start_slot: int = _current_page * SLOTS_PER_PAGE + 1
	var end_slot: int = start_slot + SLOTS_PER_PAGE - 1
	for slot_num in range(start_slot, end_slot + 1):
		var folder_name: String = "save_%03d" % slot_num
		var slot_path: String = "user://saves/" + folder_name + "/"
		var screenshot_path: String = slot_path + "screenshot.png"
		var manifest: Dictionary = SaveManager.read_slot_manifest("user://saves/", slot_num)
		var slot_data: Dictionary = {
			"slot_number": slot_num,
			"folder_name": folder_name,
			"path": slot_path,
			"timestamp": "",
			"screenshot_path": screenshot_path if FileAccess.file_exists(screenshot_path) else "",
			"exists": not manifest.is_empty(),
			"world_seed": 0,
			"floor_level": 0,
			"game_time_sec": 0.0,
		}
		if not manifest.is_empty():
			slot_data["timestamp"] = manifest.get("saved_at", "")
			slot_data["world_seed"] = int(manifest.get("world_seed", 0))
			slot_data["floor_level"] = int(manifest.get("floor_level", 0))
			slot_data["game_time_sec"] = float(manifest.get("game_time_sec", 0.0))
		_save_slots.append(slot_data)


### Tiles + detail plaque ------------------------------------------------------------

func _populate_tiles() -> void:
	for slot: Dictionary in _save_slots:
		var tile: Button = _tiles.get(int(slot["slot_number"]))
		if tile == null:
			continue
		_style_tile(tile, slot)
		_apply_selection()


func _apply_selection() -> void:
	for slot_number in _tiles:
		var tile: Button = _tiles[slot_number]
		var slot: Dictionary = _slot_for_number(slot_number)
		_style_tile(tile, slot)


func _slot_for_number(slot_number: int) -> Dictionary:
	for slot: Dictionary in _save_slots:
		if int(slot.get("slot_number", -1)) == slot_number:
			return slot
	return {"slot_number": slot_number, "exists": false}


func _select_default_slot() -> void:
	var chosen: int = 0
	for slot: Dictionary in _save_slots:
		if slot.get("exists", false):
			chosen = int(slot["slot_number"])
			break
	if chosen == 0 and not _save_slots.is_empty():
		chosen = int(_save_slots[0].get("slot_number", 0))
	_selected_slot = chosen
	_apply_selection()
	_fill_detail()


func _on_tile_pressed(slot_number: int) -> void:
	_selected_slot = slot_number
	_apply_selection()
	_fill_detail()


func _update_subline() -> void:
	if _mode == "save":
		_subline.text = "write over any frame . page %d of %d" % [_current_page + 1, TOTAL_PAGES]
	else:
		_subline.text = "select a path to read its entry . page %d of %d" % [_current_page + 1, TOTAL_PAGES]


func _fill_detail() -> void:
	if _detail == null:
		return
	var slot: Dictionary = _slot_for_number(_selected_slot)
	var filled: bool = slot.get("exists", false)
	if filled:
		_detail.text = "Slot %d\n%s\nSeed %d . Floor %d\n%.0f sec in" % [
			_selected_slot, str(slot.get("timestamp", "")),
			int(slot.get("world_seed", 0)), int(slot.get("floor_level", 0)),
			float(slot.get("game_time_sec", 0.0))]
	else:
		_detail.text = "Slot %d is empty." % _selected_slot
	_delete_btn.visible = filled
	if _mode == "save":
		_action_btn.text = "save here" if filled else "begin a path here"
	else:
		_action_btn.text = "continue from here" if filled else "this frame is empty"
		_action_btn.disabled = not filled
		if _action_btn.disabled:
			_action_btn.text = "this frame is empty"


func _on_action_pressed() -> void:
	if _selected_slot <= 0:
		return
	if _mode == "save":
		_do_save(_selected_slot)
	else:
		_do_load(_selected_slot)


### Slot interaction (the unchanged contract) ----------------------------------------

func _do_save(slot_number: int) -> void:
	var success: bool = SaveManager.save_to_slot(slot_number)
	operation_completed.emit(success,
			"Game saved to slot %d!" % slot_number if success else "Save failed!")
	if success:
		queue_free()


func _do_load(slot_number: int) -> void:
	var slot: Dictionary = _slot_for_number(slot_number)
	if not slot.get("exists", false):
		operation_completed.emit(false, "Slot %d is empty!" % slot_number)
		return
	if not SaveManager.begin_load(slot_number).is_empty():
		operation_completed.emit(true, "Loading slot %d..." % slot_number)
		SaveManager.start_loaded_game()
	else:
		operation_completed.emit(false, "Load failed!")


### Page navigation -------------------------------------------------------------------

func _on_page_button_pressed(page: int) -> void:
	if page == _current_page:
		return
	_current_page = page
	_update_page_button_highlight()
	_selected_slot = 0
	_scan_save_slots()
	_populate_tiles()
	_select_default_slot()
	_update_subline()


func _update_page_button_highlight() -> void:
	var page_box: VBoxContainer = null
	for child in get_children():
		if child is MarginContainer:
			var mc: MarginContainer = child
			for child2 in mc.get_children():
				if child2 is VBoxContainer:
					page_box = child2
	if page_box == null:
		return
	for row: Node in page_box.get_children():
		if not row is HBoxContainer:
			continue
		for btn_node: Node in (row as HBoxContainer).get_children():
			var btn: Button = btn_node as Button
			if btn == null:
				continue
			var is_current: bool = int(btn.get_meta("page", -1)) == _current_page
			btn.add_theme_color_override("font_color", COL_TEXT if is_current else COL_MUTED)


### Removal (confirm popup) -----------------------------------------------------------

func _on_delete_pressed() -> void:
	if _delete_popup != null and is_instance_valid(_delete_popup):
		return
	var slot: Dictionary = _slot_for_number(_selected_slot)
	if not slot.get("exists", false):
		return
	_delete_pending = _selected_slot
	var popup: PopupPanel = PopupPanel.new()
	popup.title = "Remove this entry"
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(460, 140)
	popup.add_child(vbox)
	var label: Label = Label.new()
	label.text = "Remove %s and delete everything in it? This cannot be undone." % str(slot.get("folder_name", ""))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label)
	var btn_hbox: HBoxContainer = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_hbox)
	var cancel_btn: Button = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 36)
	cancel_btn.pressed.connect(func() -> void:
		_close_delete_popup()
	)
	btn_hbox.add_child(cancel_btn)
	var delete_btn2: Button = Button.new()
	delete_btn2.text = "Delete"
	delete_btn2.custom_minimum_size = Vector2(120, 36)
	delete_btn2.pressed.connect(_on_delete_confirmed)
	btn_hbox.add_child(delete_btn2)
	add_child(popup)
	popup.popup_centered()
	_delete_popup = popup


func _on_delete_confirmed() -> void:
	_close_delete_popup()
	var slot_number: int = _delete_pending
	_delete_pending = 0
	if slot_number == 0:
		return
	var folder: String = str(_slot_for_number(slot_number).get("folder_name", ""))
	if folder == "" or not SaveManager.delete_save(folder):
		return
	_selected_slot = 0
	_scan_save_slots()
	_populate_tiles()
	_select_default_slot()


func _close_delete_popup() -> void:
	if _delete_popup != null and is_instance_valid(_delete_popup):
		_delete_popup.queue_free()
	_delete_popup = null
