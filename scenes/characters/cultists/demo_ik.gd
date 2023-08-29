extends Node

enum DemoState {
	NONE,
	STOPPED,
	IK
}

export var tween_duration = 5.0

var demo_state : int = DemoState.NONE
var tween
onready var ik_look_target = $"%IKLookTarget"
onready var always_on_skeleton_ik = $"%AlwaysOnSkeletonIK"

func _ready():
	ik_look_target.set_as_toplevel(true)

func _process(delta):
	var player = GameManager.game.player as Spatial
	if is_instance_valid(player):
		var pos = player.global_translation
		pos.y += 1.5
		ik_look_target.global_translation = pos

func _unhandled_input(event):
	if event.is_action_pressed("demo|ik_toggle"):
		demo_state = (demo_state + 1)%DemoState.size()
		match demo_state:
			DemoState.NONE:
				$"%BehaviorTree".set_physics_process(true)
				if tween is SceneTreeTween:
					tween.kill()
				tween = null
				always_on_skeleton_ik.interpolation = 0.0
			DemoState.STOPPED:
				(owner as Character).character_state.move_direction = Vector3.ZERO
				$"%BehaviorTree".set_physics_process(false)
			DemoState.IK:
				if tween is SceneTreeTween:
					tween.kill()
				tween = get_tree().create_tween()
				tween.tween_property(always_on_skeleton_ik, "interpolation", 1.0, tween_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
		print("Current Demo State : ", demo_state)
