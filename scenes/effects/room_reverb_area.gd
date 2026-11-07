class_name RoomReverbArea
extends Area3D

## One per generated room: a box area matching the room's footprint. When the
## player's body enters, this area re-parameterizes the ONE shared "Reverb"
## audio bus from the room's size (issue #179). The effect has dry = 1.0, so
## the dry sound is untouched and only the wet tail tracks the room size.
## Rooms without an area (corridors, outdoors) fall back to the small
## default params. The bus is AudioServer state created at runtime, never
## project.godot state.

const BUS_NAME : String = "Reverb"
# Sends to Effects, not Master: the player's breathing rides this bus and
# must keep responding to the existing "Effects Volume" slider.
const SEND_BUS : String = "Effects"
const PLAYER_GROUP : String = "PLAYER"
const ROOM_AREA_GROUP : String = "room_reverb_areas"

# Room size range for the mapping, in meters. SMALL is a 2x2 cell room
# (WorldData.CELL_SIZE = 1.5 m), LARGE approximates the biggest halls.
const SMALL_SIZE_METERS : float = 3.0
const LARGE_SIZE_METERS : float = 24.0

# Mapping endpoints: small rooms are barely wet and tight, big halls get a
# long, darker, later-arriving tail. See docs/research/room_reverb_report.md.
const WET_SMALL : float = 0.06
const WET_LARGE : float = 0.40
const ROOM_SIZE_SMALL : float = 0.12
const ROOM_SIZE_LARGE : float = 0.85
# damping is a 0..1 tail-darkening coefficient: small rooms stay bright,
# big halls get absorbed highs.
const DAMPING_SMALL : float = 0.2
const DAMPING_LARGE : float = 0.8
const PREDELAY_MSEC_SMALL : float = 15.0
const PREDELAY_MSEC_LARGE : float = 70.0
const DRY : float = 1.0

# Room box size in meters, applied by SpawnData as a custom property before
# the node enters the tree (same mechanism as the room fog volumes).
var size : Vector3 = Vector3.ONE


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group(ROOM_AREA_GROUP)
	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		add_child(collision_shape)
	var box := BoxShape3D.new()
	box.size = size
	collision_shape.shape = box
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	body_entered.disconnect(_on_body_entered)
	body_exited.disconnect(_on_body_exited)


### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------


## Creates the shared reverb bus if it does not exist and returns its index.
## Idempotent and safe from any caller (areas, character audio setup).
static func ensure_reverb_bus() -> int:
	var bus_index := AudioServer.get_bus_index(BUS_NAME)
	if bus_index != -1:
		return bus_index
	AudioServer.add_bus()
	bus_index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, BUS_NAME)
	AudioServer.set_bus_send(bus_index, SEND_BUS)
	var reverb := AudioEffectReverb.new()
	reverb.dry = DRY
	AudioServer.add_bus_effect(bus_index, reverb)
	return bus_index


## Pure mapping from a room's interior size in meters to reverb parameters.
static func params_for_room_size(room_size_meters : Vector2) -> Dictionary:
	var longest : float = clampf(
		maxf(room_size_meters.x, room_size_meters.y),
		SMALL_SIZE_METERS, LARGE_SIZE_METERS)
	var t : float = (longest - SMALL_SIZE_METERS) / (LARGE_SIZE_METERS - SMALL_SIZE_METERS)
	return {
		"wet": lerpf(WET_SMALL, WET_LARGE, t),
		"room_size": lerpf(ROOM_SIZE_SMALL, ROOM_SIZE_LARGE, t),
		"damping": lerpf(DAMPING_SMALL, DAMPING_LARGE, t),
		"predelay_msec": lerpf(PREDELAY_MSEC_SMALL, PREDELAY_MSEC_LARGE, t),
		"dry": DRY,
	}


## Small, nearly dry fallback for spaces without a room area. Dry stays 1.0,
## so the default is a small room, never silence.
static func default_params() -> Dictionary:
	return {
		"wet": 0.04,
		"room_size": 0.08,
		"damping": DAMPING_SMALL,
		"predelay_msec": PREDELAY_MSEC_SMALL,
		"dry": DRY,
	}


## Writes the parameters onto the shared bus's reverb effect, observable via
## AudioServer. Missing bus or effect is a recoverable condition: warn and
## leave audio untouched.
static func apply_reverb_params(params : Dictionary) -> void:
	var bus_index := AudioServer.get_bus_index(BUS_NAME)
	if bus_index == -1:
		push_warning("RoomReverbArea: reverb bus not created yet")
		return
	var reverb : AudioEffectReverb = AudioServer.get_bus_effect(bus_index, 0) as AudioEffectReverb
	if reverb == null:
		push_warning("RoomReverbArea: reverb bus has no reverb effect")
		return
	reverb.dry = params["dry"]
	reverb.wet = params["wet"]
	reverb.room_size = params["room_size"]
	reverb.damping = params["damping"]
	reverb.predelay_msec = params["predelay_msec"]


### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------


func _on_body_entered(body : Node3D) -> void:
	if body.is_in_group(PLAYER_GROUP):
		apply_reverb_params.call_deferred(params_for_room_size(Vector2(size.x, size.z)))


func _on_body_exited(body : Node3D) -> void:
	if body.is_in_group(PLAYER_GROUP):
		_handle_player_exit.call_deferred()


## Only falls back to defaults when the player overlaps no other room area,
## so adjacent boxes overlapping inside a shared wall never stomp each other.
func _handle_player_exit() -> void:
	if _player_overlaps_another_room():
		return
	apply_reverb_params(default_params())


func _player_overlaps_another_room() -> bool:
	for area in get_tree().get_nodes_in_group(ROOM_AREA_GROUP):
		var room_area := area as RoomReverbArea
		if room_area == null or room_area == self:
			continue
		for body in room_area.get_overlapping_bodies():
			if body.is_in_group(PLAYER_GROUP):
				return true
	return false
