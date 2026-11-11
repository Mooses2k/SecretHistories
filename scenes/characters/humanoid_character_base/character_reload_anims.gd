extends Node
## Character-side reload animation coordinator (Phases 2 and 4 of the reload
## animation port). Rebuilds the 3.x player_anims.reload_weapons() layer on
## the active humanoid base: small guns (item_size SMALL, 3.x item_size 0)
## unequip the offhand item before the character clip fires and re-equip
## whatever the offhand slot holds on completion or abort (issue #644
## bullet 3; 3.x unequipped ANY offhand item, not just lights). Guns ride in
## through HumanoidCharacter.play_reload_animation(), the same seam shape as
## play_melee_attack().
##
## Phase 4 adds left-hand reparenting: the Lee-Metford and Martini-Henry
## rifle composites were authored with the gun riding the LEFT hand (their
## clips key the gun pose relative to it), so a reload_needs_left_hand gun
## reparents to the offhand mount (PalmL/OffHandRoot) for the reload and
## reparents back to MainHandRoot on every exit path, global transform kept
## on both directions so the swap never pops.

## The tracked gun while its staged reload runs. Null outside a reload.
var _gun : EquipmentItem = null

## Whether the offhand held an item at the press: only then does the
## re-equip at the end fire (a bare offhand stays bare).
var _offhand_was_equipped : bool = false

## Whether the tracked gun is currently mounted on the offhand (Phase 4
## left-hand guns only). Drives the restore on every exit path.
var _reparented : bool = false

## Single-shot end guard: completion, abort and teardown must each run the
## restore exactly once per tracked reload (G2/G3/G7).
var _ended : bool = false

@onready var _character : HumanoidCharacter = owner as HumanoidCharacter


## Arms the coordinator for one gun press. The gun-side reload() already
## refuses a second press while one runs, so a tracked reload here is a
## no-op re-entry (G1).
func start_reload(gun : EquipmentItem) -> void:
	if _gun != null and is_instance_valid(_gun):
		return
	_gun = gun
	_ended = false
	_reparented = false
	_offhand_was_equipped = _character.inventory.current_offhand_equipment != null
	# 3.x order: the offhand leaves BEFORE the character clip fires. Owner
	# ruling (2026-11-09, #644): this clear is a put-away, so a lit light is
	# EXTINGUISHED here and the re-equip returns the same slot's item unlit.
	# Phase 4: a left-hand long gun needs the left hand as a mount, so it
	# clears the offhand too.
	if (gun.item_size == GlobalConsts.ItemSize.SIZE_SMALL \
			or gun.get("reload_needs_left_hand") == true) and _offhand_was_equipped:
		_character.inventory.extinguish_stowed_light(_character.inventory.current_offhand_equipment)
		_character.inventory.unequip_offhand_item()
	# Phase 4: the left-hand gun rides the offhand mount while the reload
	# runs. reparent() keeps the global transform, so the mount swap itself
	# does not pop; the composite takes over from its first frame (the
	# gun-side hook runs the coordinator BEFORE _start_reload_composite).
	if gun.get("reload_needs_left_hand") == true:
		_mount_left_hand_gun(gun)
	# The character clip fires through the tree OneShot named by the gun's
	# space-free item_name (3.x trigger: parameters/" + str(item_name) +
	# "/active; 4.x BlendTree strips spaces from node names).
	_character.animation_tree.fire_reload_one_shot(StringName(gun.item_name))
	gun.connect("reload_stage_finished", _on_reload_stage_finished)
	gun.connect("reload_aborted", _on_reload_aborted)


func _on_reload_stage_finished(loaded_amount : int) -> void:
	_end_reload()


func _on_reload_aborted() -> void:
	# The abort arrives AFTER the gun's close beat (the gun-side holds
	# is_reloading through it), so this is already past the owner's
	# cylinder-closes-first rule.
	_end_reload()


func _notification(what : int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_exit_tree_guard()


func _exit_tree_guard() -> void:
	# G6: scene exit/unload mid-reload. A scene change tears the whole
	# character subtree (the mounted gun included) down together, so the
	# restore is defensive only: a partial teardown must never leave the
	# gun on the wrong hand. No inventory work here (the scene is going).
	if _gun != null and _reparented and is_instance_valid(_gun) \
			and _gun.item_state == GlobalConsts.ItemState.EQUIPPED \
			and _character != null and _character.main_hand_root != null \
			and _gun.get_parent() == _character.off_hand_root:
		_gun.reparent(_character.main_hand_root)
	_gun = null


func _mount_left_hand_gun(gun : EquipmentItem) -> void:
	var mount : Node3D = _character.off_hand_root
	if mount == null or gun.get_parent() == null:
		return
	# reparent() keeps the global transform by default.
	gun.reparent(mount)
	_reparented = true


## Restores the Phase 4 mount exactly once (G2/G3): back to MainHandRoot
## with the global transform kept and the main-hand hold pose re-applied
## (the composite ends at the gun scene's authored pose, which was authored
## relative to the left-hand mount). A gun that left the mainhand mid-reload
## (dropped, unequipped, death-dropped) stays a world body (G4).
func _restore_left_hand_gun() -> void:
	if not _reparented:
		return
	_reparented = false
	if not is_instance_valid(_gun):
		return
	if _gun.item_state != GlobalConsts.ItemState.EQUIPPED:
		return
	var hand : Node3D = _character.main_hand_root
	if hand != null and _gun.get_parent() == _character.off_hand_root:
		_gun.reparent(hand)
		_gun.transform = _gun.get_hold_transform()


## Whether the offhand may return at the end of this reload. Phase 4 premise
## flag: the Lee-Metford and Martini-Henry rifles are SIZE_MEDIUM, and
## equip_offhand_item's own guard answers a medium mainhand gun by
## unequipping it (the inventory's two-hands rule). While that gun stays
## mainhand the offhand cannot legitimately come back; it returns as soon
## as the gun leaves the mainhand (or for small guns, always).
func _offhand_may_return() -> bool:
	var mainhand : EquipmentItem = _character.inventory.current_mainhand_equipment
	if mainhand == null:
		return true
	if mainhand.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM and mainhand is GunItem:
		return false
	return true


func _end_reload() -> void:
	if _ended:
		return
	_ended = true
	if _gun == null:
		return
	if is_instance_valid(_gun):
		if _gun.is_connected("reload_stage_finished", _on_reload_stage_finished):
			_gun.disconnect("reload_stage_finished", _on_reload_stage_finished)
		if _gun.is_connected("reload_aborted", _on_reload_aborted):
			_gun.disconnect("reload_aborted", _on_reload_aborted)
		_restore_left_hand_gun()
		# Re-equip whatever the offhand slot now holds. Blind re-equip is
		# 3.x parity for small guns: if the player changed the offhand slot
		# mid-reload, the new slot's item comes back instead.
		# equip_offhand_item() carries the 0.5 s internal delay that matches
		# the 3.x re-equip grace. G2/G3/G7: exactly once, on every exit path.
		if _offhand_was_equipped and _offhand_may_return():
			_character.inventory.equip_offhand_item()
		# Wind the character clip down when it is still running: in Phase 2
		# the clamped Lee-Metford and Martini-Henry chains finished ahead of
		# their clips; with the Phase 4 unclamp the chains equal the clip
		# length, so this is now a no-op on natural completion and still
		# cuts the clip on an abort. ABORT cuts (this build's FADE_OUT
		# request only plays the clip to its end before fading,
		# engine-verified) and is a no-op once the OneShot has already
		# auto-released at its clip end.
		_character.animation_tree.abort_reload_one_shot(StringName(_gun.item_name))
	_gun = null
	_offhand_was_equipped = false
