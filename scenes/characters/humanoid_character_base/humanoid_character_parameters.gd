extends Node
class_name HumanoidCharacterParameters

@export_group("Movement")
@export_range(0.0, 10.0, 0.1,"or_greater", "suffix:m/s") var base_speed : float = 1.1
@export_range(0.0, 10.0, 0.1,"or_greater", "suffix:m/s²") var base_acceleration : float = 10.0
@export_range(0.0, 90, 0.1, "radians_as_degrees") var min_slope_angle : float = deg_to_rad(30)
@export_range(0.0, 90, 0.1, "radians_as_degrees") var max_slope_angle : float = deg_to_rad(45)
@export_range(0.0, 10.0, 0.1,"or_greater", "suffix:m/s") var jump_speed : float = 4.0
@export var jump_control_multiplier : float = 0.5
@export var crouch_speed_multiplier : float = 0.5
# Sprint multiplier at max stamina
@export var sprint_speed_multiplier_max : float = 3.0
# Sprint multiplier as stamina goes to 0
@export var sprint_speed_multiplier_min : float = 1.5

@export_group("Collision")
@export var standing_height : float = 1.7
@export var crouch_height : float = 1.2

@export_group("Animation")
@export_range(0.0, 1.0, 0.05, "or_greater", "suffix:s") 
var crouch_animation_duration : float = 0.2
@export_range(0.0, 360, 1.0, "or_greater", "radians_as_degrees", "suffix:°/s") 
var turning_speed : float = TAU

@export_group("Stamina")
@export var max_stamina : float = 600.0
@export_range(0.0, 100.0, 1.0, "or_greater", "suffix:/s") 
var stamina_drain_rate : float = 18.0

@export_group("Kick")
@export var kick_stamina_cost : float = 50.0
@export_range(0.0, 5.0, 0.05, "or_greater", "suffix:s") 
var kick_cooldown : float = 1.0
@export var kick_max_speed : float = 10.0
@export var kick_impulse : float = 7.0
@export var kick_damage : int = 15
@export var kick_damage_type : GlobalConsts.AttackTypes
