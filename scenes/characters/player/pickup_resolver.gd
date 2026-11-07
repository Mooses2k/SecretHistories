class_name PickupResolver
extends RefCounted

## Pure-logic helpers for shapecast-based item pickup (issues #735 and #736).
## The physics sphere casts live in interact_controller.gd; this file is the
## single home for candidate filtering, ranking, and same-type grouping so the
## pickup rules have exactly one implementation.

## Ranking rule (issue #736): the candidate with the smallest perpendicular
## distance to the camera ray wins. Ties break by the shorter distance along
## the ray, so among equally off-ray hits the one closest to the camera is
## picked. Squared-distance epsilon keeps float jitter from flip-flopping.
const RANK_EPSILON_SQ : float = 0.0001


## Arbitration helper (issue #736): tiny and key items under the crosshair
## always win pickup, so they block hold-to-grab capture. Equipment and
## everything else keep the tap-picks-hold-drags timing split.
static func outranks_drag(item : PickableItem) -> bool:
	return item is TinyItem or item is KeyItem


static func filter_pick_candidates(bodies : Array, inventory : Inventory, tiny_only : bool = false) -> Array[PickableItem]:
	# Keep only bodies the inventory can actually pick up. can_pickup_item is
	# the canonical validation (dropped state plus pickup-legal types), so
	# doors, paintings, statues, and equipped or busy items never become
	# pickup candidates.
	var picks : Array[PickableItem] = []
	for body in bodies:
		var item := body as PickableItem
		if item == null:
			continue
		if inventory != null and not inventory.can_pickup_item(item):
			continue
		if tiny_only and not outranks_drag(item):
			continue
		picks.append(item)
	return picks


static func select_best(candidates : Array[PickableItem], ray_origin : Vector3, ray_direction : Vector3) -> PickableItem:
	var direction := ray_direction.normalized()
	var best : PickableItem = null
	var best_perpendicular_sq := INF
	var best_along := INF
	for item in candidates:
		var offset := item.global_position - ray_origin
		var along := offset.dot(direction)
		# Behind the camera is not under the crosshair.
		if along < 0.0:
			continue
		var perpendicular_sq : float = max(offset.length_squared() - along * along, 0.0)
		var better := false
		if perpendicular_sq < best_perpendicular_sq - RANK_EPSILON_SQ:
			better = true
		elif perpendicular_sq <= best_perpendicular_sq + RANK_EPSILON_SQ and along < best_along:
			better = true
		if better:
			best = item
			best_perpendicular_sq = perpendicular_sq
			best_along = along
	return best


## Kind identity for group pickup (issue #735): the TinyItemData resource
## identity for TinyItem, the key id for KeyItem. A null data resource means
## the key-id kind is active; a key id of -1 matches nothing, so an anchor
## with no kind data collects alone.
static func matches_group_kind(item : PickableItem, data : Resource, key_id : int) -> bool:
	var tiny := item as TinyItem
	if tiny != null:
		return data != null and tiny.item_data == data
	var key := item as KeyItem
	if key != null:
		return data == null and key.key_id == key_id
	return false
