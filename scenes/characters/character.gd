extends RigidBody
class_name Character

signal character_died()

export(Array, AttackTypes.Types) var immunities : Array
export var max_health : int = 100
export var move_speed : float = 8.0
export var acceleration : float = 32.0

onready var character_state : CharacterState = CharacterState.new(self)

onready var current_health : float = self.max_health
var _current_velocity : Vector3 = Vector3.ZERO
var _type_damage_multiplier : PoolByteArray
var _alive : bool = true

#func _init():
#	mode = MODE_CHARACTER
#	self.physics_material_override = preload("res://scenes/characters/character.phymat")

func _ready():
	_type_damage_multiplier.resize(AttackTypes.Types.TYPE_COUNT)
	for i in _type_damage_multiplier.size():
		_type_damage_multiplier[i] = 1
	for immunity in self.immunities:
		_type_damage_multiplier[immunity] = 0


func _integrate_forces(state):
	handle_elevation(state)
	handle_movement(state)
#	var vertical_velocity = self._current_velocity.y
#	self._current_velocity.y = 0
#
#	self.move_direction.y = 0
#	self.move_direction = self.move_direction.normalized()*min(1.0, self.move_direction.length())
#	var target_velocity : Vector3 = self.move_direction*self.move_speed
#	var velocity_diff = target_velocity - self._current_velocity
#	var velocity_correction = velocity_diff.normalized()*min(self.acceleration*delta, velocity_diff.length())
#	self._current_velocity += velocity_correction
#
#	self._current_velocity = self.move_and_slide(self._current_velocity, Vector3.UP)

#Stays at y = 0, raycast later
func handle_elevation(state : PhysicsDirectBodyState):
	var diff_correction = -Vector3.UP*state.transform.origin.y*mass/state.step
	var speed_correction = -Vector3.UP*state.linear_velocity.y*mass
	var gravity_correction = -state.total_gravity*mass*state.step
	apply_central_impulse(diff_correction + speed_correction + gravity_correction)

func handle_movement(state : PhysicsDirectBodyState):
	var planar_velocity = state.linear_velocity
	planar_velocity.y = 0
	var target_velocity : Vector3 = character_state.move_direction*move_speed
	var velocity_diff = target_velocity - planar_velocity
	var velocity_correction = velocity_diff.normalized()*min(acceleration*state.step, velocity_diff.length())
	apply_central_impulse(velocity_correction*mass)

func damage(value : float, type : int):
	if self._alive:
		self.current_health -= self._type_damage_multiplier[type]*value
		if self.current_health <= 0:
			self._alive = false
			self.emit_signal("character_died")
			self.queue_free()
