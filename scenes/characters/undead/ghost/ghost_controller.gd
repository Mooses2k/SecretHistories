extends Node


var chasing : bool = false setget set_chasing

onready var detection_area : Area = get_node("../DetectionArea") as Area
onready var damage_area : Area = get_node("../DamageArea") as Area
onready var character = owner

onready var target_position : Vector3 = self.global_transform.origin


func _process(delta):
	self.update_target()
	self.character.character_state.move_direction = target_position - self.global_transform.origin


func update_target():
	for body in self.detection_area.get_overlapping_bodies():
		if body.is_in_group(Groups.CHARACTER):
			self.target_position = body.global_transform.origin
			self.chasing = true
			return
	self.chasing = false
	if self.target_position.distance_to(self.global_transform.origin) < 0.1:
		var level = GameManager.game.level
		if level:
			var x : int = rand_range(0, level.world_size)
			var z : int = rand_range(0, level.world_size)
			self.target_position = level.grid_to_world(Vector3(x, 0, z).floor())
			print_debug("going to ", self.target_position)


func set_chasing(value : bool):
	if chasing != value:
		chasing = value
		if value == true:
			print("chasing player")
		else:
			print("patrolling")
