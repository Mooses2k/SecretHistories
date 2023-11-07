#
# This is a simplified door model, with toggle open/close
# Done due to limitations in Godot 3 making it difficult to implement
# a fully simulated Rigid Body door
#

extends Spatial
class_name BaseKinematicDoor



enum DoorState {
	OPEN,
	CLOSED,
	STUCK
}

var navigation_areas : Array
var door_state : int = DoorState.CLOSED

var door_move_time = 0.5
var door_open_angle = deg2rad(100)
var door_close_threshold = deg2rad(5)
var door_speed = door_open_angle/door_move_time
var door_should_move = false

onready var door_body = $"%DoorBody"
onready var door_hinge_z_axis = $"%DoorHingeZAxis"
onready var open_block_detector = $"%OpenBlockDetector"
onready var close_block_detector = $"%CloseBlockDetector"
onready var doorway_gaps_filler = $"%DoorwayGapsFiller"
onready var npc_detector = $"%NpcDetector"

func _physics_process(delta):
	if not door_should_move:
		return
	match door_state:
		DoorState.OPEN:
			if door_hinge_z_axis.rotation.y < door_open_angle:
				for obstacle in open_block_detector.get_overlapping_bodies():
					if not obstacle in [door_body, doorway_gaps_filler]:
						door_should_move = false
						if door_hinge_z_axis.rotation.y < door_close_threshold:
							door_state = DoorState.CLOSED
							door_should_move = true
						return
				door_hinge_z_axis.rotation.y = move_toward(door_hinge_z_axis.rotation.y, door_open_angle, door_speed*delta)
		DoorState.CLOSED:
			if door_hinge_z_axis.rotation.y > 0.0:
				for obstacle in close_block_detector.get_overlapping_bodies():
					if not obstacle in [door_body, doorway_gaps_filler]:
						door_should_move = false
						if door_hinge_z_axis.rotation.y > door_close_threshold:
								door_state = DoorState.OPEN
								if door_hinge_z_axis.rotation.y > door_open_angle - door_close_threshold:
									door_should_move = true
						return
				door_hinge_z_axis.rotation.y = move_toward(door_hinge_z_axis.rotation.y, 0.0, door_speed*delta)
		DoorState.STUCK:
			door_should_move = false
			pass

func _on_Interactable_character_interacted(character):
	match door_state:
		DoorState.CLOSED:
			door_state = DoorState.OPEN
			door_should_move = true
		DoorState.OPEN:
			door_state = DoorState.CLOSED
			door_should_move = true
		DoorState.STUCK:
			pass


func _on_NpcDetector_body_entered(body):
	door_state = DoorState.OPEN
	door_should_move = true


func _on_NpcCheckTimer_timeout():
	if npc_detector.get_overlapping_bodies().size() > 0:
		door_state = DoorState.OPEN
		door_should_move = true
