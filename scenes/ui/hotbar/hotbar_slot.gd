extends Control


const CONTAINER_COUNT_TEMPLATE = "%d + %d"   # Typically how much ammo in weapon / ammo total

@export var can_equip_modulate : Color
@export var equipped_modulate : Color
@export var can_not_equip_modulate : Color

var item : EquipmentItem = null: set = set_item
var tracking_tiny_item = null
var inventory = null: set = set_inventory
@export var index : int = -1
@export var is_bulky : bool  = false

var is_equipped_mainhand : bool = false
var is_equipped_offhand : bool = false
var is_equippable_mainhand : bool = false
var is_equippable_offhand : bool = false

@onready var fadeanimations = $"../../FadeAnim"
@onready var ammo_count: Label = $ItemInfo/HBoxContainer/AmmoCount
@onready var item_name_label: Label = $ItemInfo/HBoxContainer/ItemName


func _ready():
	var game = GameManager.game
	var player = game.player
	if player == null:
		await game.player_spawned
		player = game.player
	if player.inventory == null:
		await player.ready
	inventory = player.inventory

	#TODO: fix this when inventory is updated
	fadeanimations.play("Fade_in")
	$"../..".show()
	if self.name == "10":
		$SlotNumber.text = str(index+1)
	else:
		$SlotNumber/HBoxContainer/SlotNumber.text=str(index+1)


#func _physics_process(delta):
	#if is_equipped_mainhand or is_equipped_offhand:
		#update_container_data()


func update_mainhand_indicator():
	var final_color = can_equip_modulate if is_equippable_mainhand else can_not_equip_modulate
	final_color = equipped_modulate if is_equipped_mainhand else final_color
	$UseIndicators/HBoxContainer/MainHandIndicator.modulate = final_color
	if is_equipped_mainhand:
		is_equipped_offhand = false
	if is_bulky:
		$SlotNumber/HBoxContainer/SlotNumber.text = str("Bulky")
		$UseIndicators.visible = false


func update_offhand_indicator():
	var final_color = can_equip_modulate if is_equippable_offhand else can_not_equip_modulate
	final_color = equipped_modulate if is_equipped_offhand  else final_color
	$UseIndicators/HBoxContainer/OffHandIndicator.modulate = final_color
	if is_equippable_offhand:
		is_equipped_offhand = false


func set_item(value : EquipmentItem):
	if item != value:
		if is_instance_valid(item):
			item.item_data_changed.disconnect(update_item_data)
		item = value
		update_item_data()
		if is_instance_valid(item):
			item.item_data_changed.connect(update_item_data)


func set_inventory(value : Node):
	inventory = value
	if not is_bulky:
		inventory_slot_changed(index)
	else:
		inventory_bulky_item_changed()
	update_equipped_status()
	inventory.hotbar_changed.connect(inventory_slot_changed)
	inventory.bulky_item_changed.connect(inventory_bulky_item_changed)
	inventory.tiny_item_changed.connect(inventory_tiny_item_changed)
	inventory.mainhand_slot_changed.connect(inventory_mainhand_slot_changed)
	inventory.offhand_slot_changed.connect(inventory_offhand_slot_changed)
	inventory.inventory_changed.connect(hud_visibility)
	inventory.player_died.connect(hide_hud)


func hide_hud():
	self.owner.visible = false


func hud_visibility():
		fadeanimations.play("Fade_in")
		$"../..".show()
		update_name()


func inventory_bulky_item_changed():
	if is_bulky:
		self.item = inventory.bulky_equipment
		self.visible = item != null
		update_equipped_status()
	else:
		update_equipped_status()


func inventory_mainhand_slot_changed(previous : int, current : int):
	if index == previous or index == current:
		update_equipped_status()


func inventory_offhand_slot_changed(previous : int, current : int):
	if index == previous or index == current:
		update_equipped_status()


func update_equipped_status():
	if is_bulky:
		is_equipped_mainhand = item != null and inventory.bulky_equipment == item
		is_equipped_offhand = is_equipped_mainhand
		is_equippable_mainhand = true
		is_equippable_offhand = true
	else:
		is_equippable_mainhand = true
		is_equippable_offhand = item == null or item.item_size == GlobalConsts.ItemSize.SIZE_SMALL
		is_equipped_mainhand = index == inventory.current_mainhand_slot and inventory.bulky_equipment == null
		is_equipped_offhand = index == inventory.current_offhand_slot and inventory.bulky_equipment == null
	update_mainhand_indicator()
	update_offhand_indicator()


func inventory_slot_changed(slot : int):
	if slot == index:
		self.item = inventory.hotbar[slot]


func inventory_tiny_item_changed(tiny_item : TinyItemData, previous : int, current : int):
	if tiny_item == tracking_tiny_item:
		update_container_data()


func update_item_data():
	update_name()
	update_container_data()
	update_equipped_status()


func update_name():
	if item == null:
		item_name_label.text = ""
	else:
		if item.stackable_resource != null and item.stackable_resource.items_stacked.size() > 1:
			item_name_label.text = str(item.stackable_resource.items_stacked.size()) + "x " + item.stackable_resource.stack_name
			pass
		else:
			item_name_label.text = item.item_name


func update_container_data():   # Things like gun ammo, charges in medical bags, etc
	# temporary hack (issue #409)
	if not is_instance_valid(item):
		item = null

	if item is GunItem:
		var current_ammo = item.current_ammo
		var ammo_type = item.current_ammo_type if item.current_ammo_type != null else item.ammo_types.front()
		var inv_ammo = 0
		if ammo_type != null and (inventory.tiny_items as Dictionary).has(ammo_type):
			inv_ammo = inventory.tiny_items[ammo_type]
		tracking_tiny_item = ammo_type
		ammo_count.text = CONTAINER_COUNT_TEMPLATE % [current_ammo, inv_ammo]
	elif item is MedicalItem:
		if item.max_charges_held > 1:   # In other words, not a single-use consumable
			ammo_count.text = CONTAINER_COUNT_TEMPLATE % [item.charges_held, item.max_charges_held]
	else:
		tracking_tiny_item = null
		ammo_count.text = ""


func _on_Fade_animation_finished(anim_name):
	if anim_name=="Fade_in":
		fadeanimations.play("Fade_out")
