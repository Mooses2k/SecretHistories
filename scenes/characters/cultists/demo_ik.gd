extends Node

### Purpose of this is to stop the cultist in his tracks, then turn head to look at camera.
### This is to provide for a cool scene for the demo trailer.


enum DemoState {
	NONE,
	STOPPED,
	IK
}

export var tween_duration = 5.0

var demo_state : int = DemoState.NONE
var tween_value : float = 0.0
var tween
onready var ik_look_target = $"%IKLookTarget"
onready var always_on_skeleton_ik = $"%AlwaysOnSkeletonIK"
onready var ik_base_target = $"%IKBaseTarget"


func _ready():
	ik_look_target.set_as_toplevel(true)
	update_ik_target(tween_value)


func _process(delta):
	update_ik_target(tween_value)


func update_ik_target(t : float):
	if GameManager.game:   # True unless this is a test scene
		var player = GameManager.game.player as Spatial
		if is_instance_valid(player):
			var pos = player.global_translation
			pos.y += 1.5
			ik_look_target.global_translation = ik_base_target.global_translation.linear_interpolate(pos, t)


func _unhandled_input(event):
	if event.is_action_pressed("demo|ik_toggle"):
		demo_state = (demo_state + 1) % DemoState.size()
		match demo_state:
			DemoState.NONE:
				if is_instance_valid($"%BehaviorTree"):
					$"%BehaviorTree".set_process(true)
				if tween is SceneTreeTween:
					tween.kill()
				tween = null
				tween_value = 0.0
				
				# Keep the interpolation value above 0.01, because Godot does
				# weird stuff when it's below that value, and the transition
				# causes a sudden jump in the IK
				always_on_skeleton_ik.interpolation =- 0.011
			DemoState.STOPPED:
				(owner as Character).character_state.move_direction = Vector3.ZERO
				if is_instance_valid($"%BehaviorTree"):
					$"%BehaviorTree".set_process(false)
			DemoState.IK:
				if tween is SceneTreeTween:
					tween.kill()
				tween = get_tree().create_tween()
				tween.tween_property(always_on_skeleton_ik, "interpolation", 1.0, tween_duration)
				tween.parallel().tween_property(self, "tween_value", 1.0, tween_duration).from(0.0)
		print("Demo IK look-at state : ", demo_state)
