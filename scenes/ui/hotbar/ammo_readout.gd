extends VBoxContainer

## Noct-style qualitative ammo readout shown above the hotbar (issue #661).
## One line per ammunition type the player has encountered, owned or not:
## "type: None|Few|Some|Lots". Total ammo owned per type, never exact counts.

const WORD_NONE := "None"
const WORD_FEW := "Few"
const WORD_SOME := "Some"
const WORD_LOTS := "Lots"

# Owner-tunable thresholds: Few is 1-5, Some is 6-19, Lots is 20 and up
const FEW_MAX := 5
const SOME_MAX := 19

const LINE_TEMPLATE := "%s: %s"

var inventory = null


static func amount_word(amount: int) -> String:
	if amount <= 0:
		return WORD_NONE
	if amount <= FEW_MAX:
		return WORD_FEW
	if amount <= SOME_MAX:
		return WORD_SOME
	return WORD_LOTS


func _ready() -> void:
	var game = GameManager.game
	var player = game.player
	if player == null:
		await game.player_spawned
		player = game.player
	if player.inventory == null:
		await player.ready
	inventory = player.inventory
	inventory.tiny_item_changed.connect(_on_inventory_changed)
	inventory.hotbar_changed.connect(_on_inventory_changed)
	inventory.bulky_item_changed.connect(_on_inventory_changed)
	_rebuild()


func _exit_tree() -> void:
	if inventory == null:
		return
	inventory.tiny_item_changed.disconnect(_on_inventory_changed)
	inventory.hotbar_changed.disconnect(_on_inventory_changed)
	inventory.bulky_item_changed.disconnect(_on_inventory_changed)


func _on_inventory_changed(_a = null, _b = null, _c = null) -> void:
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if inventory == null:
		return
	for ammo in _known_ammo_types():
		var label := Label.new()
		label.text = LINE_TEMPLATE % [ammo.name, amount_word(inventory.tiny_item_amount(ammo))]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)


## Ammunition types the readout lists (owner ruling): a type shows ONLY when
## its matching gun is NOT in the inventory. A carried gun's caliber is hidden
## until the gun is gone; types with no gun in the inventory show as before.
func _known_ammo_types() -> Array[AmmunitionData]:
	var hidden := _carried_gun_ammo_types()
	var types: Array[AmmunitionData] = []
	for entry in inventory.known_tiny_items:
		var item := entry as TinyItemData
		if item is AmmunitionData and not hidden.has(item) and not types.has(item):
			types.append(item)
	types.sort_custom(_sort_by_name)
	return types


func _collect_gun_ammo(item, types: Array[AmmunitionData]) -> void:
	if item is GunItem:
		for ammo in item.ammo_types:
			var ammo_data := ammo as AmmunitionData
			if ammo_data != null and not types.has(ammo_data):
				types.append(ammo_data)


## Ammo types of every gun the player currently carries (hotbar slots plus
## bulky equipment): the set of types hidden from the readout.
func _carried_gun_ammo_types() -> Array[AmmunitionData]:
	var types: Array[AmmunitionData] = []
	for slot_item in inventory.hotbar:
		_collect_gun_ammo(slot_item, types)
	_collect_gun_ammo(inventory.bulky_equipment, types)
	return types


func _sort_by_name(a: AmmunitionData, b: AmmunitionData) -> bool:
	return a.name < b.name
