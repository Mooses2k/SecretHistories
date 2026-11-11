extends Node
## Character-side reload animation coordinator (Phase 2 of the reload
## animation port). Rebuilds the 3.x player_anims.reload_weapons() layer on
## the active humanoid base: small guns (item_size SMALL, 3.x item_size 0)
## unequip the offhand item before the character clip fires and re-equip
## whatever the offhand slot holds on completion or abort (issue #644
## bullet 3; 3.x unequipped ANY offhand item, not just lights). Guns ride in
## through HumanoidCharacter.play_reload_animation(), the same seam shape as
## play_melee_attack().

## The tracked gun while its staged reload runs. Null outside a reload.
var _gun : EquipmentItem = null

## Whether the offhand held an item at the press: only then does the
## re-equip at the end fire (a bare offhand stays bare).
var _offhand_was_equipped : bool = false

@onready var _character : HumanoidCharacter = owner as HumanoidCharacter


## Arms the coordinator for one gun press. The gun-side reload() already
## refuses a second press while one runs, so a tracked reload here is a
## no-op re-entry.
func start_reload(gun : EquipmentItem) -> void:
	if _gun != null and is_instance_valid(_gun):
		return
	_gun = gun
	_offhand_was_equipped = _character.inventory.current_offhand_equipment != null
	# 3.x order: the offhand leaves BEFORE the character clip fires. The
	# unequip keeps the item in its hotbar slot (no extinguish for a lit
	# light: 3.x never extinguished on unequip and the dev4 light-fuel rules
	# forbid a silent stow extinguish), so the re-equip brings the SAME item
	# back in its current state.
	if gun.item_size == GlobalConsts.ItemSize.SIZE_SMALL and _offhand_was_equipped:
		_character.inventory.unequip_offhand_item()
	# The character clip fires through the tree OneShot named by the gun's
	# exact item_name (3.x trigger: parameters/" + str(item_name) + "/active).
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


func _end_reload() -> void:
	if _gun == null:
		return
	if is_instance_valid(_gun):
		if _gun.is_connected("reload_stage_finished", _on_reload_stage_finished):
			_gun.disconnect("reload_stage_finished", _on_reload_stage_finished)
		if _gun.is_connected("reload_aborted", _on_reload_aborted):
			_gun.disconnect("reload_aborted", _on_reload_aborted)
		# Re-equip whatever the offhand slot now holds. Blind re-equip is
		# 3.x parity: if the player changed the offhand slot mid-reload, the
		# new slot's item comes back instead. equip_offhand_item() carries
		# the 0.5 s internal delay that matches the 3.x re-equip grace, and
		# its medium-gun guard cannot fire here (a small gun stays mainhand).
		if _offhand_was_equipped:
			_character.inventory.equip_offhand_item()
		# Wind the character clip down when it is still running: the clamped
		# Lee-Metford and Martini-Henry chains finish ahead of their clips
		# (3.0 s vs 11.4 s and 3.133 s). ABORT cuts (the tree ships zero
		# fade times; this build's FADE_OUT request only plays the clip to
		# its end before fading, engine-verified), and it is a no-op once
		# the OneShot has already auto-released at its clip end (every
		# unclamped gun's chain outlasts its clip).
		_character.animation_tree.abort_reload_one_shot(StringName(_gun.item_name))
	_gun = null
	_offhand_was_equipped = false
