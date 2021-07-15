extends KinematicBody
class_name Character

signal character_died()

export(Array, AttackTypes.Types) var immunities : Array
export var max_health : int = 100
export var move_speed : float = 8.0
export var acceleration : float = 32.0

var move_direction : Vector3 = Vector3.ZERO



onready var current_health : float = self.max_health
var _current_velocity : Vector3 = Vector3.ZERO
var _type_damage_multiplier : PoolByteArray
var _alive : bool = true

func _ready():
	_type_damage_multiplier.resize(AttackTypes.Types.TYPE_COUNT)
	for i in _type_damage_multiplier.size():
		_type_damage_multiplier[i] = 1
	for immunity in self.immunities:
		_type_damage_multiplier[immunity] = 0


func _physics_process(delta : float):
	if self._alive:
		self._handle_movement(delta)


func _handle_movement(delta : float):
	var vertical_velocity = self._current_velocity.y
	self._current_velocity.y = 0
	
	self.move_direction.y = 0
	self.move_direction = self.move_direction.normalized()*min(1.0, self.move_direction.length())
	var target_velocity : Vector3 = self.move_direction*self.move_speed
	var velocity_diff = target_velocity - self._current_velocity
	var velocity_correction = velocity_diff.normalized()*min(self.acceleration*delta, velocity_diff.length())
	self._current_velocity += velocity_correction
	
	self._current_velocity = self.move_and_slide(self._current_velocity, Vector3.UP)


func damage(value : float, type : int):
	if self._alive:
		self.current_health -= self._type_damage_multiplier[type]*value
		if self.current_health <= 0:
			self._alive = false
			self.emit_signal("character_died")
			self.queue_free()
