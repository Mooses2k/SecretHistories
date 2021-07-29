extends Node

enum States {
	WANDER,
	FOLLOW,
	GRAB,
}

export var max_wander = 6.0
export var wander_speed_factor : float = 0.6

onready var character = get_parent() as Character
onready var body = $"../Body" as Spatial
onready var view_area = $"../Body/ViewArea" as Area
onready var view_raycast = $"../Body/ViewRayCast" as RayCast

var current_state = States.WANDER

var path : Array = []

var last_known_player_position : Vector3 = Vector3.UP*10000
var player_visible = false

var speed_multiplier : float = 1.0

func _physics_process(delta):
	handle_state()
	update_view()
	update_state()
	
	pass # Replace with function body.

func update_wander_target():	
	if path.size() == 0:
		var level = GameManager.game.level
		if level:
			var direction = Vector3.RIGHT.rotated(Vector3.UP, randf()*2*PI)
			var distance = randf()*max_wander
			var desired_target = character.global_transform.origin + direction*distance
			var actual_target = GameManager.game.level.navigation.get_closest_point(desired_target)
			path = GameManager.game.level.navigation.get_simple_path(character.global_transform.origin, actual_target)

func handle_state():
	match current_state:
		States.WANDER:
			update_wander_target()
			speed_multiplier = wander_speed_factor
			follow_path()
			return
		States.FOLLOW:
			path = GameManager.game.level.navigation.get_simple_path(character.global_transform.origin, last_known_player_position)
			speed_multiplier = 1.0
			follow_path()
			return
		States.GRAB:
			return

func follow_path():
	while path.size() > 0 and path[0].distance_to(character.global_transform.origin) < 1.0:
		path.pop_front()
	if path.size() > 0:
		character.move_direction = path[0] - character.global_transform.origin
		character.move_direction = character.move_direction.normalized()*speed_multiplier
		var facing = character.move_direction + character.linear_velocity
		facing.y = 0
		if not facing.is_equal_approx(Vector3.ZERO):
			body.look_at(facing + body.global_transform.origin, Vector3.UP)
	pass

func update_state():
	match current_state:
		States.FOLLOW:
			if not player_visible and character.global_transform.origin.distance_to(last_known_player_position) < 1.0:
				current_state = States.WANDER
			pass
		States.GRAB:
			pass
		States.WANDER:
			if player_visible:
				current_state = States.FOLLOW
				character.move_direction = Vector3.ZERO

func update_view():
	for body in view_area.get_overlapping_bodies():
		if body is Player:
			var player : Player = body as Player
			view_raycast.look_at(player.global_transform.origin, Vector3.UP)
			view_raycast.force_raycast_update()
			if view_raycast.is_colliding() and view_raycast.get_collider() == player:
				last_known_player_position = player.global_transform.origin
				player_visible = true
				return
	player_visible = false
