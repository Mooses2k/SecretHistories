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


onready var fadeanimations=$"../../FadeAnim"

var is_equipped_primary : bool = false 
var is_equipped_secondary : bool = false
var is_equippable_primary : bool = false
var is_equippable_secondary : bool = false

func update_primary_indicator():
	var final_color = can_equip_modulate if is_equippable_primary else can_not_equip_modulate
	final_color = equipped_modulate if is_equipped_primary else final_color
	$"UseIndicators/HBoxContainer/PrimaryIndicator".modulate = final_color

func update_secondary_indicator():
	var final_color = can_equip_modulate if is_equippable_secondary else can_not_equip_modulate
	final_color = equipped_modulate if is_equipped_secondary else final_color
	$"UseIndicators/HBoxContainer/SecondaryIndicator".modulate = final_color

func set_item(value : EquipmentItem):
	item = value
	update_item_data()

func _ready():
	fadeanimations.play("Fade_in")
	$"../..".show()
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
	inventory.connect("primary_slot_changed", self, "inventory_primary_slot_changed")
	inventory.connect("secondary_slot_changed", self, "inventory_secondary_slot_changed")
	inventory.connect("UpdateHud",self, "Hud_visibility")
	
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

func inventory_primary_slot_changed(previous : int, current : int):
	if index == previous or index == current:
		update_equipped_status()


func inventory_secondary_slot_changed(previous : int, current : int):
	if index == previous or index == current:
		update_equipped_status()

func update_equipped_status():

	if is_bulky:
		is_equipped_primary = item != null and inventory.bulky_equipment == item
		is_equipped_secondary = is_equipped_primary
		is_equippable_primary = true
		is_equippable_secondary = true
	else:
		is_equippable_primary = true
		is_equippable_secondary = item == null or item.item_size == GlobalConsts.ItemSize.SIZE_SMALL
		is_equipped_primary = index == inventory.current_primary_slot and inventory.bulky_equipment == null
		is_equipped_secondary = index == inventory.current_secondary_slot and inventory.bulky_equipment == null
	update_primary_indicator()
	update_secondary_indicator()

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
	if is_equipped_primary or is_equipped_secondary:
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
