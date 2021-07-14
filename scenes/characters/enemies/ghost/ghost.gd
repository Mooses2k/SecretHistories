extends KinematicBody

const SPEED = 2.0

var target = null
var vel = Vector3()
var path = null

var health = 200

onready var hitbox = $HitboxArea
onready var game_world = get_parent()
onready var player = game_world.get_node("Player")
onready var navigation : Navigation = game_world.navigation
func _ready():
	self.set_physics_process(false)
	
	hitbox.connect("body_entered", self, "on_hit_player")
	
	var timer = Timer.new()
	timer.wait_time = 0.1
	add_child(timer)
	timer.connect("timeout", self, "find_path_timer")
	timer.start()
	

func _process(delta):
	if health <= 0:
		queue_free()


func _physics_process(delta):

	self.look_at(target.global_transform.origin, Vector3.UP)
	
	if path.size() > 0:
		move_along_path(path)

		
	
func move_along_path(path):
	if global_transform.origin.distance_to(path[0]) < 0.1:
		path.remove(0)
		if path.size() == 0:
			return
	
	vel = (path[0] - global_transform.origin).normalized() * SPEED
	vel = move_and_slide(vel)
	
	
func set_target(target):
	self.target = target
	self.set_physics_process(true)
#	find_path_timer()
	
	
func on_hit_player(body):
	if body.name == "Player":
		body.die()
		$Whisper.stop()
		$Growl.play()
		
	
func find_path_timer():
	self.set_target(player)
	path = navigation.get_simple_path(global_transform.origin, target.global_transform.origin)
	path.remove(0)
#	path = path_finder.find_path(global_transform.origin, target.global_transform.origin)
	
