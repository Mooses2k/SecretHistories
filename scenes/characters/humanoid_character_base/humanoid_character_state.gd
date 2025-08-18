extends Node
class_name HumanoidCharacterState

# Things like being stunned, or ragdolled
enum PhysicalState {
	NORMAL, # Normal state, can move around freely and do whatever
	KNOCKED_OUT,
	DEAD
}

signal physical_state_changed(new_physical_state : PhysicalState)

var physical_state : PhysicalState = PhysicalState.NORMAL :
	set(value):
		physical_state = value
		physical_state_changed.emit(value)

var stamina_ratio : float:
	get():
		return stamina / parameters.max_stamina

var is_on_ground : bool = false
var was_on_ground : bool = false
# 0.0 means fully standing, 1.0 means fully crouching
var current_crouch_ratio : float = 0.0
var facing : Basis = Basis.IDENTITY
var sprinting : bool = false
var is_reloading : bool = false
var time_since_kick : float = INF
var time_since_dodge : float = INF
var noclip_enabled : bool = false
var knocked_out_timer : float = 0.0

var _hurtboxes : Array[Hurtbox]

@onready var parameters: HumanoidCharacterParameters = $"../Parameters" as HumanoidCharacterParameters
@onready var input: HumanoidCharacterInput = $"../Input" as HumanoidCharacterInput
@onready var stamina : float = parameters.max_stamina:
	set(value):
		stamina = clampf(value, 0.0, parameters.max_stamina)

@onready var durability : int = parameters.max_durability : set = set_durability

func _ready() -> void:
	_collect_hurtboxes.call_deferred()

func set_facing_vector(forward : Vector3) -> void:
	facing = Basis.looking_at(-forward, Vector3.UP, true)

func get_facing_vector() -> Vector3:
	return -facing.z

func should_jump():
	return is_on_ground and input.jump

func set_durability(value : int) -> void:
	durability = value
	if durability <= 0:
		physical_state = PhysicalState.DEAD

func get_target_speed() -> float:
	var crouch_multiplier = lerpf(1.0, parameters.crouch_speed_multiplier, current_crouch_ratio)
	var sprint_multiplier = lerpf(
		parameters.sprint_speed_multiplier_min,
		parameters.sprint_speed_multiplier_max,
		stamina_ratio
	)
	sprint_multiplier = sprint_multiplier if sprinting else 1.0
	return parameters.base_speed*crouch_multiplier*sprint_multiplier


func _physics_process(delta: float) -> void:
	time_since_kick += delta
	time_since_dodge += delta
	if physical_state == PhysicalState.KNOCKED_OUT:
		knocked_out_timer += delta
		if knocked_out_timer > parameters.knocked_out_time:
			physical_state = PhysicalState.NORMAL
			knocked_out_timer = 0.0

func is_controllable() -> bool:
	return physical_state == PhysicalState.NORMAL

func _collect_hurtboxes() -> void:
	var queue := owner.get_children()
	while not queue.is_empty():
		var child := queue.pop_front() as Node
		if child.owner == owner:
			if child is Hurtbox:
				_hurtboxes.push_back(child)
			queue.append_array(child.get_children())
	for h in _hurtboxes:
		h.damaged.connect(_on_damaged.bind(h))

func is_ragdolled() -> bool:
	match physical_state:
		PhysicalState.DEAD, PhysicalState.KNOCKED_OUT:
			return true
		_:
			return false

func _on_damaged(amount : int, type : GlobalConsts.AttackTypes, direction : Vector3, origin : Vector3, hurtbox : Hurtbox) -> void:
	print("Damaged ", owner.name, " by ", amount)
	if amount > parameters.ragdoll_damage_threshold or is_ragdolled():
		physical_state = PhysicalState.KNOCKED_OUT
		var bone := hurtbox.get_parent() as PhysicalBone3D
		if is_instance_valid(bone):
			bone.apply_central_impulse.call_deferred(amount * direction * parameters.ragdoll_impulse_multiplier)
	durability -= amount
	pass
