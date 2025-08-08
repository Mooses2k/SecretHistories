extends Node


@onready var hand_target_r: Marker3D = $"../../ModelRoot/HandTargetR"
@onready var hand_target_l: Marker3D = $"../../ModelRoot/HandTargetL"

@onready var idle_hand_r: Marker3D = $"../../ModelRoot/MainCamera/IdleHandPositions/HandR"
@onready var idle_hand_l: Marker3D = $"../../ModelRoot/MainCamera/IdleHandPositions/HandL"

@onready var look_target: Marker3D = $"../../ModelRoot/LookTarget"
@onready var camera_dir: Marker3D = $"../../ModelRoot/MainCamera/CameraDir"


func _process(delta: float) -> void:
	hand_target_r.global_transform = idle_hand_r.global_transform
	hand_target_l.global_transform = idle_hand_l.global_transform
	look_target.global_transform = camera_dir.global_transform
