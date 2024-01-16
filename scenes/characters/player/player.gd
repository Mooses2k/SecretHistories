class_name Player
extends Character


var mainhand_orig_origin = null
var offhand_orig_origin = null
var is_change_main_equip_out : bool = false
var is_change_main_equip_in : bool = false
var is_change_off_equip_out : bool = false
var is_change_off_equip_in : bool = false

var light_resource = preload("res://scenes/objects/pickable_items/equipment/tool/light-sources/candle_lantern/candle_lantern.tscn")
var light2_resource = preload("res://scenes/objects/pickable_items/equipment/tool/light-sources/omnidirectional_lantern/omni_lantern.tscn")
var spyglass_resource = preload("res://scenes/objects/pickable_items/tiny/spyglass/spyglass.tscn")

onready var player_controller = $PlayerController
onready var tinnitus = $Tinnitus
onready var fps_camera = $FPSCamera
onready var gun_cam = $FPSCamera/ViewportContainer/Viewport/GunCam   # Fixed fov player viewport so stuff doesn't go through walls
onready var player_animation_tree = $"%AnimationTree"
onready var hit_effect = $HitEffect
onready var player_animations_test = $"%PlayerAnimationsTest"
onready var player_animations = $PlayerAnimations
onready var player_gun_reload_shells = $"%GunReloadShells"


func _ready():
	if not is_connected("player_landed", player_controller, "_on_Player_player_landed"):
		connect("player_landed", player_controller, "_on_Player_player_landed")
	mainhand_orig_origin = mainhand_equipment_root.transform.origin
	offhand_orig_origin = offhand_equipment_root.transform.origin
	
	# Add initial equipment to player
#	inventory.add_item(spyglass_resource.instance())
#	inventory.add_item(light2_resource.instance())
#	print("player.gd added oil lantern")
#	inventory.set_mainhand_slot(2)s
	inventory.add_item(light_resource.instance())
	print("player.gd added candle")


func _process(_delta: float) -> void:
	# TODO: This should probably be in character.gd
	if is_reloading == true:
		if noise_level < 8:
			noise_level = 8
			$Audio/NoiseTimer.start()
			
	if light_level > 0.003:   # Maybe ensure this is the same as the detection light-level as another way for the player to know when they're in darkness
#		$KinestheticSense.visible = false
		$KinestheticSense/Tween.interpolate_property($KinestheticSense, "light_energy", $KinestheticSense.light_energy, 0.0, 1.0)
		$KinestheticSense/Tween.start()
#		print("Lit up, kinesthetic sense fading: ", $KinestheticSense.light_energy)
	else:
#		$KinestheticSense.visible = true
		$KinestheticSense/Tween.interpolate_property($KinestheticSense, "light_energy", $KinestheticSense.light_energy, 0.2, 1.0)
		$KinestheticSense/Tween.start()
#		print("In the dark, kinesthetic sense increasing: ", $KinestheticSense.light_energy)
