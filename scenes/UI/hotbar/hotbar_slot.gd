extends Control


const AMMO_COUNT_TEMPLATE = "%d+%d"

export var can_equip_modulate : Color
export var equipped_modulate : Color
export var can_not_equip_modulate : Color

var item : EquipmentItem = null setget set_item
var tracking_tiny_item= null
var inventory = null setget set_inventory
export var index : int = -1
export var is_bulky : bool  = false

var is_equipped_mainhand : bool = false 
var is_equipped_offhand : bool = false
var is_equippable_mainhand : bool = false
var is_equippable_offhand : bool = false

onready var fadeanimations=$"../../FadeAnim"


func update_mainhand_indicator():
	var final_color = can_equip_modulate if is_equippable_mainhand else can_not_equip_modulate
	final_color = equipped_modulate if is_equipped_mainhand else final_color
	$UseIndicators/HBoxContainer/MainHandIndicator.modulate = final_color
	if is_equipped_mainhand:
		is_equipped_offhand = false


func update_offhand_indicator():
	var final_color = can_equip_modulate if is_equippable_offhand else can_not_equip_modulate
	final_color = equipped_modulate if is_equipped_offhand  else final_color
	$UseIndicators/HBoxContainer/OffHandIndicator.modulate = final_color
	if is_equippable_offhand:
		is_equipped_offhand = false


func set_item(value : EquipmentItem):
	item = value
	update_item_data()


func _ready():
	fadeanimations.play("Fade_in")
	$"../..".show()
	if self.name == "10":
		$SlotNumber.text=str(index+1)
	else:
		$SlotNumber/HBoxContainer/SlotNumber.text=str(index+1)
	var game = GameManager.game
	var player = game.player
	if player == null:
		yield(game, "player_spawned")
		player = game.player
	if player.inventory == null:
		yield(player, "ready")
		inventory = player.inventory
	self.inventory = player.inventory


func set_inventory(value : Node):
	inventory = value
	if not is_bulky:
		inventory_slot_changed(index)
	else:
		inventory_bulky_item_changed()
	update_equipped_status()
	inventory.connect("hotbar_changed", self, "inventory_slot_changed")
	inventory.connect("bulky_item_changed", self, "inventory_bulky_item_changed")
	inventory.connect("tiny_item_changed", self, "inventory_tiny_item_changed")
	inventory.connect("mainhand_slot_changed", self, "inventory_mainhand_slot_changed")
	inventory.connect("offhand_slot_changed", self, "inventory_offhand_slot_changed")
	inventory.connect("UpdateHud",self, "Hud_visibility")
	inventory.connect("PlayerDead",self, "hide_HUD")


func hide_HUD():
	self.owner.visible = false


func Hud_visibility():
		fadeanimations.play("Fade_in")
		$"../..".show()


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
		update_ammo_data()
	pass


func update_item_data():
	update_name()
	update_ammo_data()
	update_equipped_status()


func _physics_process(delta):
	if is_equipped_mainhand or is_equipped_offhand:
		update_ammo_data()


func update_name():
	$"ItemInfo/HBoxContainer/ItemName".text = item.item_name if item else ""


func update_ammo_data():
	if item is GunItem:
		var current_ammo = item.current_ammo
		var ammo_type = item.current_ammo_type if item.current_ammo_type != null else item.ammo_types.front()
		var inv_ammo = 0
		if ammo_type != null and (inventory.tiny_items as Dictionary).has(ammo_type):
			inv_ammo = inventory.tiny_items[ammo_type]
		tracking_tiny_item = ammo_type
		$"ItemInfo/HBoxContainer/AmmoCount".text = AMMO_COUNT_TEMPLATE % [current_ammo, inv_ammo]
	else:
		tracking_tiny_item = null
		$"ItemInfo/HBoxContainer/AmmoCount".text = ""


func _on_Fade_animation_finished(anim_name):
	if anim_name=="Fade_in":
		fadeanimations.play("Fade_out")
