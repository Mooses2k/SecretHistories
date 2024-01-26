class_name Cultist
extends Character


var weapon_resource = preload("res://scenes/objects/pickable_items/equipment/ranged/double-barrel_shotgun/double-barrel_shotgun.tscn")
var ammo_resource = preload("res://resources/tiny_items/ammunition/shotgun_shell.tres")

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


func _ready():
	inventory.add_item(weapon_resource.instantiate())   # Auto-equips it
	print("cultist.gd added shotgun")
	inventory.insert_tiny_item(ammo_resource, 555)
	print("cultist.gd added shotgun ammo")
