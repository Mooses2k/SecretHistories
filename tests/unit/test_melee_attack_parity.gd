# Tests for the one-button melee grammar (Interface wiki, melee lane fix).
# Pins:
# 1. Dispatch: LMB tap = cut swing, LMB held past the controller's
#    use_held_threshold = one thrust. RMB is not an attack surface
#    (playerhand|mainhand_secondary is gone from the input map).
# 2. Cooldown gating: a second attack during cooldown is a no-op on both
#    dispatch paths, the cooldown timer actually runs, and its timeout clears
#    the attack flags.
# 3. Damage application through the Hurtbox path: a thrust applies the primary
#    pair once each, a cut the secondary pair once each, one hit consumes
#    can_hit, own hurtboxes are skipped.
# 4. Animation requests: the attack entry points ask the owning character for
#    the right one-shot (attack name + hand) scaled by melee_attack_speed, set
#    the 3.x attack noise (thrust 8, cut 10), and stay silent during cooldown.
# 5. The character-side mapping: HumanoidCharacter.play_melee_attack fires the
#    matching parameters/<name>/request one-shot on the CharacterAnimationTree.
# The attack entry points need the scene's Sounds/CooldownTimer nodes, so the
# item tests instantiate the melee base scene.
extends GutTest

const MELEE_SCENE := preload("res://scenes/objects/pickable_items/equipment/melee/_melee_item.tscn")
const CHARACTER_SCENE := preload("res://scenes/characters/humanoid_character_base/humanoid_character_base.tscn")

const AUTHORED_P1 := 7
const AUTHORED_P1_TYPE := 2
const AUTHORED_P2 := 5
const AUTHORED_P2_TYPE := 3
const AUTHORED_S1 := 6
const AUTHORED_S1_TYPE := 1
const AUTHORED_S2 := 4
const AUTHORED_S2_TYPE := 4


class RecordingCharacter extends Node:
	var melee_requests : Array = []
	var noises : Array = []
	var inventory : Inventory = null

	func play_melee_attack(attack, left_hand, attack_speed = 1.0):
		melee_requests.append([attack, left_hand, attack_speed])

	func apply_attack_noise(level):
		noises.append(level)


# A bare Inventory subclass: the hand getters run the production logic over
# the real equipment slots the test fills in.
class StubInventory extends Inventory:
	pass


class RecordingHurtbox extends Hurtbox:
	var damage_calls : Array = []

	func damage(amount : int, type : GlobalConsts.AttackTypes, direction := Vector3.ZERO, origin := Vector3.ZERO):
		damage_calls.append([amount, type])


func _make_item() -> MeleeItem:
	var item : MeleeItem = MELEE_SCENE.instantiate()
	item.primary_damage1 = AUTHORED_P1
	item.primary_damage_type1 = AUTHORED_P1_TYPE
	item.primary_damage2 = AUTHORED_P2
	item.primary_damage_type2 = AUTHORED_P2_TYPE
	item.secondary_damage1 = AUTHORED_S1
	item.secondary_damage_type1 = AUTHORED_S1_TYPE
	item.secondary_damage2 = AUTHORED_S2
	item.secondary_damage_type2 = AUTHORED_S2_TYPE
	add_child_autofree(item)
	return item


func _make_character() -> RecordingCharacter:
	var character : RecordingCharacter = RecordingCharacter.new()
	character.inventory = StubInventory.new()
	autofree(character.inventory)
	autofree(character)
	return character


func test_tap_releases_into_a_cut():
	var item := _make_item()
	item.use_primary()
	assert_true(item.did_a_cut, "a tap cuts (wiki: LMB tap = Cut)")
	assert_false(item.did_a_thrust, "a tap does not thrust")
	assert_true(item.on_cooldown, "a tap starts the cooldown")
	assert_true(item.can_hit, "the cut hit is armed")


func test_hold_crosses_the_threshold_into_one_thrust():
	var item := _make_item()
	item.set_held_use(true)
	assert_true(item.did_a_thrust, "a hold thrusts (wiki: LMB held = thrust)")
	assert_false(item.did_a_cut, "a hold does not cut")
	assert_true(item.on_cooldown, "a hold starts the cooldown")
	assert_true(item.is_held(), "the hold state stays raised until release")
	item.set_held_use(false)
	assert_false(item.is_held(), "releasing lowers the hold")
	assert_true(item.did_a_thrust and not item.did_a_cut, "releasing after a hold fires no second attack")


func test_cooldown_blocks_a_second_attack():
	var item := _make_item()
	var character := _make_character()
	item.owner_character = character
	item.use_primary()
	assert_true(item.on_cooldown, "precondition: the tap started the cooldown")
	item.can_hit = false
	var requests_before : int = character.melee_requests.size()
	item.use_primary()
	assert_false(item.can_hit, "a tap during cooldown does not arm the hitbox again")
	assert_eq(character.melee_requests.size(), requests_before, "a tap during cooldown fires no animation request")
	item.set_held_use(true)
	assert_false(item.did_a_thrust, "a hold during cooldown does not thrust")
	assert_true(item.get_node("CooldownTimer").get_time_left() > 0.0, "the cooldown timer is actually running")


func test_cooldown_timeout_clears_the_attack_flags():
	var item := _make_item()
	item.attack_cut()
	assert_true(item.on_cooldown and item.did_a_cut, "precondition: a cut is on cooldown")
	item._on_CooldownTimer_timeout()
	assert_false(item.on_cooldown, "the timeout clears on_cooldown")
	assert_false(item.did_a_cut, "the timeout clears did_a_cut")
	assert_false(item.did_a_thrust, "the timeout clears did_a_thrust")


func _make_victim() -> Node:
	var victim : Node = Node.new()
	autofree(victim)
	return victim


func test_thrust_damage_applies_the_primary_pair_once_each():
	var item := _make_item()
	var victim := _make_victim()
	var hurtbox : RecordingHurtbox = RecordingHurtbox.new()
	hurtbox.owner_node = victim
	autofree(hurtbox)
	item.attack_thrust()
	item._on_Hitbox_hit(hurtbox)
	assert_eq(hurtbox.damage_calls, [[AUTHORED_P1, AUTHORED_P1_TYPE], [AUTHORED_P2, AUTHORED_P2_TYPE]],
		"thrust applies primary1 then primary2, once each")
	assert_false(item.can_hit, "one hit consumes can_hit")


func test_cut_damage_applies_the_secondary_pair_once_each():
	var item := _make_item()
	var victim := _make_victim()
	var hurtbox : RecordingHurtbox = RecordingHurtbox.new()
	hurtbox.owner_node = victim
	autofree(hurtbox)
	item.attack_cut()
	item._on_Hitbox_hit(hurtbox)
	assert_eq(hurtbox.damage_calls, [[AUTHORED_S1, AUTHORED_S1_TYPE], [AUTHORED_S2, AUTHORED_S2_TYPE]],
		"cut applies secondary1 then secondary2, once each")
	assert_false(item.can_hit, "one hit consumes can_hit")


func test_own_hurtbox_is_skipped():
	var item := _make_item()
	var character := _make_character()
	item.owner_character = character
	var hurtbox : RecordingHurtbox = RecordingHurtbox.new()
	hurtbox.owner_node = character
	autofree(hurtbox)
	item.attack_thrust()
	item._on_Hitbox_hit(hurtbox)
	assert_eq(hurtbox.damage_calls, [], "the wielder's own hurtbox takes no melee damage")
	assert_true(item.can_hit, "a self-hit does not consume the swing")


func test_animation_requests_carry_attack_hand_and_speed():
	var item := _make_item()
	item.melee_attack_speed = 2.0
	var character := _make_character()
	item.owner_character = character
	character.inventory.current_mainhand_equipment = item
	item.use_primary()
	assert_eq(character.melee_requests, [[&"attack_cut", false, 2.0]], "a main-hand tap requests the right-hand cut one-shot")
	assert_eq(character.noises, [10.0], "a cut raises the 3.x cut noise level")
	character.melee_requests.clear()
	character.noises.clear()
	item._on_CooldownTimer_timeout()
	item.set_held_use(true)
	assert_eq(character.melee_requests, [[&"attack_thrust", false, 2.0]], "a main-hand hold requests the right-hand thrust one-shot")
	assert_eq(character.noises, [8.0], "a thrust raises the 3.x thrust noise level")
	character.melee_requests.clear()
	character.noises.clear()
	item._on_CooldownTimer_timeout()
	item.set_held_use(false)
	character.inventory.current_mainhand_equipment = null
	character.inventory.current_offhand_equipment = item
	item.use_primary()
	assert_eq(character.melee_requests, [[&"attack_cut", true, 2.0]], "an off-hand tap requests the left-hand cut one-shot")
	assert_eq(character.noises, [10.0], "a cut raises the 3.x cut noise level")


func test_rmb_attack_action_is_gone_from_the_input_map():
	assert_false(InputMap.has_action(&"playerhand|mainhand_secondary"), "the RMB attack action is removed from the input map")
	assert_true(InputMap.has_action(&"playerhand|mainhand_use"), "the one melee button (LMB) stays bound")


func test_character_tree_fires_the_matching_one_shot_parameters():
	var character : HumanoidCharacter = CHARACTER_SCENE.instantiate()
	add_child_autofree(character)
	var tree : AnimationTree = character.get_node("CharacterAnimationTree")
	character.play_melee_attack(&"attack_cut", false, 1.0)
	assert_eq(tree.get("parameters/attack_cut/request"), AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE, "right-hand cut fires attack_cut")
	character.play_melee_attack(&"attack_thrust", true, 1.5)
	assert_eq(tree.get("parameters/attack_thrust_l/request"), AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE, "left-hand thrust fires attack_thrust_l")
	assert_eq(tree.get("parameters/melee_speed/scale"), 1.5, "the speed scale carries melee_attack_speed")
