extends Node

## The cultist's AI controller: owns the blackboard and ticks the Brain HFSM
## subtree authored in neophyte.tscn. The TickTimer (10 Hz) calls tick();
## _physics_process copies the active state's movement and facing intents
## into the character input and state every physics frame, the same intent
## copy model the BT controller used. The blackboard is exposed as ai_state
## so SaveManager's ai_state.target capture and restore reads keep working
## unchanged. Weapon wiring: the controller injects the mainhand equipment
## into the combat attack states each tick, reads weapon_mode onto the
## blackboard, and throttles a mainhand equip retry while the hand is empty.

const TICK_SECONDS := 0.1
const EQUIP_RETRY_SECONDS := 1.0

@onready var character_state: HumanoidCharacterState = $"../State"
@onready var character_input: HumanoidCharacterInput = $"../Input"
@onready var look_target: Marker3D = $"../ModelRoot/LookTarget"
@onready var audio: Node = $"../Audio"
@onready var inventory: Inventory = $"../Inventory"
@onready var navigation_agent: NavigationAgent3D = $"../NavigationAgent3D"

@onready var brain: HFSM = $Brain
@onready var stimulus_adapter: StimulusAdapter = $Brain/StimulusAdapter
@onready var navigation_adapter: NavigationAdapter = $Brain/NavigationAdapter
@onready var animation_bridge: AnimationBridge = $Brain/AnimationBridge
@onready var combat: AIStateCombat = $Brain/Combat
@onready var approach: AIStateApproach = $Brain/Combat/Approach
@onready var gun_attack: AIStateGunAttack = $Brain/Combat/GunAttack
@onready var melee_attack: AIStateMeleeAttack = $Brain/Combat/MeleeAttack

## Save compatibility surface: the blackboard itself, whose target field is
## what SaveManager capture and restore read and write.
var ai_state: Blackboard = null

var _equip_cooldown := 0.0


func _ready() -> void:
	ai_state = Blackboard.new()
	navigation_adapter.character = owner
	navigation_adapter.agent = navigation_agent
	_refresh_world_data()
	_declare_transitions()
	stimulus_adapter.setup(ai_state)
	brain.setup(ai_state, navigation_adapter)
	# After setup: the bridge enumerates the machine's state children, which
	# only exist once the machine has collected them.
	animation_bridge.setup(brain, null, audio)
	character_state.physical_state_changed.connect(_on_physical_state_changed)


func _physics_process(_delta: float) -> void:
	if brain.active_state == null:
		return
	character_input.movement_vector = brain.move_intent()
	character_state.set_facing_vector(brain.face_intent())
	var target: Object = ai_state.target
	if target != null and is_instance_valid(target):
		look_target.global_position = (target as Node3D).position + Vector3.UP * 1.5


func _on_tick_timer_timeout() -> void:
	tick()


## One brain tick, called by the TickTimer at 10 Hz. Tests call this
## directly for deterministic ticks.
func tick() -> void:
	_refresh_world_data()
	_refresh_weapons()
	brain.tick(TICK_SECONDS)


func _on_physical_state_changed(new_physical_state: HumanoidCharacterState.PhysicalState) -> void:
	if new_physical_state == HumanoidCharacterState.PhysicalState.DEAD:
		ai_state.dead = true
		navigation_adapter.stop()


## The world data lives on the live level; a brain built before the level is
## ready picks it up on the first tick instead.
func _refresh_world_data() -> void:
	if navigation_adapter.world_data == null and GameManager.game != null \
			and GameManager.game.level != null:
		navigation_adapter.world_data = GameManager.game.level.world_data


## Inject the mainhand equipment into the attack states and read the weapon
## mode onto the blackboard; with an empty hand, retry the mainhand equip.
func _refresh_weapons() -> void:
	var mainhand: EquipmentItem = inventory.current_mainhand_equipment
	if mainhand is GunItem:
		gun_attack.weapon = mainhand
		gun_attack.ammo_source = inventory
		melee_attack.weapon = null
		ai_state.weapon_mode = Blackboard.WeaponMode.GUN
	elif mainhand is MeleeItem:
		melee_attack.weapon = mainhand
		gun_attack.weapon = null
		gun_attack.ammo_source = null
		ai_state.weapon_mode = Blackboard.WeaponMode.MELEE
	else:
		gun_attack.weapon = null
		gun_attack.ammo_source = null
		melee_attack.weapon = null
		ai_state.weapon_mode = Blackboard.WeaponMode.NONE
		_attempt_equip()


func _attempt_equip() -> void:
	_equip_cooldown -= TICK_SECONDS
	if _equip_cooldown > 0.0:
		return
	_equip_cooldown = EQUIP_RETRY_SECONDS
	var slot: int = inventory.current_mainhand_slot
	if slot < 0 or slot >= inventory.hotbar.size():
		return
	var slot_item: EquipmentItem = inventory.hotbar[slot] as EquipmentItem
	if slot_item != null and is_instance_valid(slot_item):
		inventory.equip_mainhand_item()


## The transition table. Declared here because AIState.Transition is an inner
## class that scene files cannot serialize; the controller is the scene's
## wiring owner. Priority is array order per state; every root state's first
## row is the death guard.
func _declare_transitions() -> void:
	var dead_row := _row("Dead", "guard_is_dead")
	var combat_row := _row("Combat", "guard_can_fight")
	var investigate_row := _row("Investigate", "guard_alert_at_least_investigate")
	var suspicious_row := _row("Suspicious", "guard_alert_raised_below_investigate")

	var idle := $Brain/Idle as AIState
	idle.transitions = [
		dead_row,
		combat_row,
		investigate_row,
		suspicious_row,
		_row("Patrol", "guard_wait_elapsed"),
	]
	var patrol := $Brain/Patrol as AIState
	patrol.transitions = [
		dead_row,
		combat_row,
		investigate_row,
		suspicious_row,
		_row("Idle", "guard_arrived"),
	]
	var suspicious := $Brain/Suspicious as AIState
	suspicious.transitions = [
		dead_row,
		combat_row,
		investigate_row,
		_row("Idle", "guard_hold_elapsed"),
	]
	var investigate := $Brain/Investigate as AIState
	investigate.transitions = [
		dead_row,
		combat_row,
		_row("Patrol", "guard_search_elapsed"),
		_row("Patrol", "guard_alert_below_investigate"),
	]
	combat.transitions = [
		dead_row,
		_row("Investigate", "guard_no_target"),
		_row("Investigate", "guard_alert_below_investigate"),
	]
	combat.initial_state = &"Approach"
	approach.transitions = [
		_row("MeleeAttack", "guard_weapon_melee"),
		_row("GunAttack", "guard_in_shoot_range"),
	]
	gun_attack.transitions = [
		_row("Approach", "guard_out_of_range"),
	]
	melee_attack.transitions = [
		_row("Approach", "guard_weapon_gun"),
	]


func _row(to_state: String, guard: String) -> AIState.Transition:
	var row := AIState.Transition.new()
	row.to_state = StringName(to_state)
	row.guard = StringName(guard)
	return row
