class_name Cultist
extends Character


var dblshotty_resource = preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_shotgun/double-barrel_shotgun.tscn")
var sawedshotty_resource = preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_sawed_shotgun/sawed-off_shotgun.tscn")
var webley_resource = preload("res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn")
var shottyammo_resource = preload("res://resources/tiny_items/ammunition/shotgun_shell.tres")
var webleyammo_resource = preload("res://resources/tiny_items/ammunition/455_webley.tres")
var oillantern_resource = preload("res://scenes/objects/pickable_items/equipment/tool/light-sources/omnidirectional_lantern/omni_lantern.tscn")
var candlelantern_resource = preload("res://scenes/objects/pickable_items/equipment/tool/light-sources/candle_lantern/candle_lantern.tscn")

@onready var direct_player_sight_sensor : Node = $Body/DirectPlayerSight
@onready var player_gun_reload_shells = %GunReloadShells

#enum #LOADOUT PACKAGES FOR NEOPHYTES:
#(# in parentheses is probability weight) {
#    (50) Double-barrel shotgun + 2 loaded + 1-3 spare + old knife/dagger
#    (10) Sawed-off shotgun + 2 loaded + 1-3 spare + oil lantern/candle lantern + old knife/dagger
#    (10) Martini-Henry rifle + 1 loaded + 2-3 spare + old knife/dagger
#    (3) Webley + 6 loaded + oil lantern/candle lantern + old knife/dagger
#    (1) Khyber-pass Martini + 1 loaded + 2-3 spare + old knife/dagger
#    (1) Lee-Metford + 1-10 loaded + 1-5 spare + old knife/dagger
#}
enum LoadoutPackage {
		DBLSHOTTY,
		SAWEDSHOTTY_OILLANTERN,
		SAWEDSHOTTY_CANDLELANTERN,
		WEBLEY_OILLANTERN,
		WEBLEY_CANDLELANTERN,
	}


func _ready():
	choose_loadout_package()


# Temp hacky version
func choose_loadout_package():
	var loadout_package = randi() % LoadoutPackage.size()

	match loadout_package:
		LoadoutPackage.DBLSHOTTY:
			inventory.add_item(dblshotty_resource.instantiate())   # Auto-equips it
			print("cultist.gd added dblshotgun")
			inventory.insert_tiny_item(shottyammo_resource, 555)
			print("cultist.gd added shotgun ammo")

		LoadoutPackage.SAWEDSHOTTY_OILLANTERN:
			inventory.add_item(sawedshotty_resource.instantiate())   # Auto-equips it
			print("cultist.gd added sawed-off shotgun")
			inventory.insert_tiny_item(shottyammo_resource, 555)
			print("cultist.gd added shotgun ammo")
			inventory.add_item(oillantern_resource.instantiate())   # Auto-equips it
			inventory.equip_offhand_item()
			print("cultist.gd added oil lantern")

		LoadoutPackage.SAWEDSHOTTY_CANDLELANTERN:
			inventory.add_item(sawedshotty_resource.instantiate())   # Auto-equips it
			print("cultist.gd added sawed-off shotty")
			inventory.insert_tiny_item(shottyammo_resource, 555)
			print("cultist.gd added shotgun ammo")
			inventory.add_item(candlelantern_resource.instantiate())   # Auto-equips it
			inventory.equip_offhand_item()
			print("cultist.gd added candle lantern")

		LoadoutPackage.WEBLEY_OILLANTERN:
			inventory.add_item(webley_resource.instantiate())   # Auto-equips it
			print("cultist.gd added dblshotgun")
			inventory.insert_tiny_item(webleyammo_resource, 555)
			print("cultist.gd added webley ammo")
			inventory.add_item(oillantern_resource.instantiate())   # Auto-equips it
			inventory.equip_offhand_item()
			print("cultist.gd added oil lantern")

		LoadoutPackage.WEBLEY_CANDLELANTERN:
			inventory.add_item(webley_resource.instantiate())   # Auto-equips it
			print("cultist.gd added dblshotgun")
			inventory.insert_tiny_item(webleyammo_resource, 555)
			print("cultist.gd added webley ammo")
			inventory.add_item(candlelantern_resource.instantiate())   # Auto-equips it
			inventory.equip_offhand_item()
			print("cultist.gd added candle lantern")
