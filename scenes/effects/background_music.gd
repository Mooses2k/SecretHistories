extends AudioStreamPlayer

# Ambience manager living on the BackgroundMusic autoload (issue #179, music
# half). The scene carries this script on the root player plus a child
# CrossfadePlayer used as the incoming side of a transition.
#
# Owner rulings baked in here:
# - Purpose tracks are their OWN track: exactly one ambient stream plays at a
#   time. Entering a purpose room crossfades from the currently playing track
#   (usually Empty) into that room's track; leaving crossfades back to Empty.
#   No overlaying, no mixing with Empty.
# - The ambient loop CONTINUES if it is the same track rather than restarting
#   on loading: an identity-checked request is a no-op, also while a crossfade
#   into that same stream is already running, so transitions never stack or
#   retrigger. The crossfade entry point never defeats the identity check.
# - The incoming track enters at the SAME RELATIVE point the outgoing track
#   is at, not always at its start and not at a random point (owner ruling,
#   superseding an earlier random-point ruling): the outgoing's normalized
#   progress through its length maps onto the incoming's length, so the two
#   tracks are at matching positions through every crossfade. Degenerate
#   lengths or a fresh track start at 0, which is correct then.
# - The crossfade is a TRUE simultaneous overlap, not an out-then-in pair
#   (owner amendment from the live pass): both players move at the same time
#   on a linear equal-gain curve in the amplitude domain (tweened through
#   volume_linear, NOT volume_db; a dB-domain tween dips at the midpoint
#   because -6 dB + -6 dB sums to half volume, which reads as fade-out-then-in).
#   The outgoing player is never stopped or gated during the fade; only the
#   rare third-stream retarget cuts the outgoing at its current volume
#   (two players cannot overlap three streams).
# - During floor loads the pre-click bus mute leaves Music unmuted, so the
#   current track keeps playing silently through the load and is audible again
#   on reveal; the room poller stands down while the tree is paused or the
#   Game's load screen is up, and the crossfade state re-resolves naturally on
#   the new floor.
#
# The root player (this node) stays the steady-state player every existing
# caller addresses: LoadScene.play_ambient, the boot menu-music switch, the
# victory screen, and the floor -5 shard-chanting stop branch. The
# CrossfadePlayer only carries the incoming stream for the ~3s a crossfade
# runs, then this node adopts it seamlessly (same bus, position, volume).
# An external stop() on this node mid-fade wins: _process aborts the fade.

const CROSSFADE_SECONDS := 3.0
const ROOM_PURPOSE_POLL_SECONDS := 0.5

const EMPTY_AMBIENCE := preload("res://resources/sounds/music/ambience_empty_(mastered).ogg")

#--- private variables - order: export > normal var > onready -------------------------------------

var _crossfade_player : AudioStreamPlayer
var _fade_tween : Tween
var _fade_active := false
# true while a fade expects this node to be playing (fading out or reversed in)
var _fade_expects_root_playing := false
var _target_stream : AudioStream = null
var _target_volume_db := 0.0
var _target_volume_linear := 1.0
var _poll_timer : Timer

### -----------------------------------------------------------------------------------------------

### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready() -> void:
	_crossfade_player = $CrossfadePlayer
	_poll_timer = Timer.new()
	_poll_timer.name = "RoomPurposePoller"
	_poll_timer.wait_time = ROOM_PURPOSE_POLL_SECONDS
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(_on_room_poll)
	add_child(_poll_timer)


func _process(_delta : float) -> void:
	# External stop() on this node during a fade (floor -5 shard branch, boot)
	# must win over the running fade: abort it and silence the incoming player.
	if _fade_active and not playing:
		_kill_fade_tween()
		_fade_active = false
		_target_stream = null
		_crossfade_player.stop()
		_crossfade_player.stream = null

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Crossfade-aware ambience request; LoadScene.play_ambient delegates here.
## Same stream already current, or already fading in: no-op (continuity
## ruling, no restart, no stacked transitions). Different stream: one
## crossfade, the outgoing track fades down while the incoming fades up, both
## at the same time, and the incoming enters at the outgoing's same relative
## point (see _relative_transfer_position).
func play_ambient(p_stream : AudioStream, p_volume_db : float = 0.0) -> void:
	if p_stream == null:
		return
	if _is_current_target(p_stream):
		return
	_begin_crossfade(p_stream, p_volume_db)


## True when p_stream is what this manager considers the current track: the
## steady stream on this node while playing, or the stream a running crossfade
## is fading in (the incoming side owns the identity during a transition).
func _is_current_target(p_stream : AudioStream) -> bool:
	if _fade_active:
		return p_stream == _target_stream
	return p_stream == self.stream and playing

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _begin_crossfade(p_stream : AudioStream, p_volume_db : float) -> void:
	_ensure_loop(p_stream)
	if _fade_active:
		if playing and p_stream == self.stream:
			# The requested track is the one still fading out on this node
			# (doorway thrash): retarget the running crossfade toward it
			# instead of cutting it, so its playback position never skips.
			_retarget_crossfade(p_stream, p_volume_db)
			return
		if _crossfade_player.stream != null and p_stream == _crossfade_player.stream:
			# The requested track is the in-flight one fading down on the
			# child (rapid enter/leave bounce right after a reversal):
			# retarget the running crossfade back toward the child's stream
			# instead of adopting it, which would cut this node's outgoing
			# track at its current gain and restart a fresh self-crossfade.
			_retarget_crossfade(p_stream, p_volume_db)
			return
		# Retargeting to a third stream: adopt the in-flight stream onto this
		# node first so the fresh crossfade starts from a normalized state.
		_kill_fade_tween()
		_adopt_crossfade_player()

	_target_stream = p_stream
	_target_volume_db = p_volume_db
	_target_volume_linear = db_to_linear(p_volume_db)
	if playing:
		# True simultaneous crossfade: outgoing on this node, incoming on the
		# child, both tweened on a linear equal-gain curve in the amplitude
		# domain (volume_linear): outgoing current gain to 0 while the child
		# goes 0 to the target gain. No threshold cut, no sequential phases.
		# The child enters at the outgoing's same relative point.
		_fade_active = true
		_fade_expects_root_playing = true
		_crossfade_player.stream = p_stream
		_crossfade_player.volume_linear = 0.0
		_crossfade_player.play(_relative_transfer_position(p_stream))
		_fade_tween = create_tween().set_parallel(true)
		_fade_tween.tween_property(self, "volume_linear", 0.0, CROSSFADE_SECONDS)
		_fade_tween.tween_property(_crossfade_player, "volume_linear",
				_target_volume_linear, CROSSFADE_SECONDS)
		_fade_tween.chain().tween_callback(_commit_crossfade)
	else:
		# Nothing is playing (boot, after a stop branch): fade in on this node
		# from its start; there is no outgoing position to transfer.
		_fade_active = true
		_fade_expects_root_playing = true
		self.stream = p_stream
		volume_linear = 0.0
		play(0.0)
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "volume_linear",
				_target_volume_linear, CROSSFADE_SECONDS)
		_fade_tween.tween_callback(_commit_crossfade)


## Retargets a running crossfade in flight: the side holding the requested
## stream fades to the target gain while the other side fades to silence.
## Tweens start from the current gains, so the transition is continuous with
## no adopt cut and no restart; _commit_crossfade then adopts whichever side
## ended up holding the target.
func _retarget_crossfade(p_stream : AudioStream, p_volume_db : float) -> void:
	_target_stream = p_stream
	_target_volume_db = p_volume_db
	_target_volume_linear = db_to_linear(p_volume_db)
	_kill_fade_tween()
	_fade_active = true
	_fade_expects_root_playing = true
	_fade_tween = create_tween().set_parallel(true)
	if p_stream == self.stream:
		# the outgoing side on this node comes back: it fades up while the
		# child's in-flight stream fades down and stops
		_fade_tween.tween_property(self, "volume_linear", _target_volume_linear, CROSSFADE_SECONDS)
		_fade_tween.tween_property(_crossfade_player, "volume_linear", 0.0, CROSSFADE_SECONDS)
	else:
		# the child holds the in-flight stream: it fades back up to the
		# target gain while this node's outgoing track fades down; no adopt,
		# no cut
		_fade_tween.tween_property(self, "volume_linear", 0.0, CROSSFADE_SECONDS)
		_fade_tween.tween_property(_crossfade_player, "volume_linear",
				_target_volume_linear, CROSSFADE_SECONDS)
	_fade_tween.chain().tween_callback(_commit_crossfade)


## End-of-fade commit: this node holds the target stream in steady state and
## the child goes idle, so external callers (menu music, stop branches) keep
## addressing a single canonical player.
func _commit_crossfade() -> void:
	_kill_fade_tween()
	_fade_active = false
	if self.stream != _target_stream:
		_adopt_crossfade_player()
	volume_db = _target_volume_db
	_crossfade_player.stop()
	_crossfade_player.stream = null


## Moves the in-flight incoming stream from the crossfade player onto this
## node without an audible seam: same bus, same volume, same playback
## position, adopted in one frame.
func _adopt_crossfade_player() -> void:
	if _crossfade_player.stream == null:
		return
	self.stream = _crossfade_player.stream
	volume_db = _crossfade_player.volume_db
	play(_crossfade_player.get_playback_position())
	_crossfade_player.stop()
	_crossfade_player.stream = null


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


## The incoming stream's entry position: the outgoing track's normalized
## progress through its own length, mapped onto the incoming's length. With
## equal lengths this is simply the same seconds. Degenerate lengths or a
## fresh outgoing start at 0, which is correct per the owner ruling.
func _relative_transfer_position(p_stream : AudioStream) -> float:
	var out_len := self.stream.get_length() if self.stream != null else 0.0
	var in_len := p_stream.get_length()
	if out_len <= 0.0 or in_len <= 0.0:
		return 0.0
	return clampf(get_playback_position() / out_len, 0.0, 1.0) * in_len


## Owner rule: ambient tracks loop. The mp3 imports default to loop=false, so
## enforce it on the stream resource at request time (idempotent).
func _ensure_loop(p_stream : AudioStream) -> void:
	if p_stream is AudioStreamMP3 or p_stream is AudioStreamOggVorbis:
		p_stream.loop = true


## Room-purpose lane driver: the player's current room decides the target
## track. Every request goes through LoadScene.play_ambient, whose identity
## check makes same-track polls free. The incoming track's entry position is
## decided by the crossfade engine itself (outgoing's same relative point).
func _on_room_poll() -> void:
	var game : Game = GameManager.game
	if game == null or not is_instance_valid(game) or not game.is_inside_tree():
		return
	# A load screen (or pause) owns the track: continuity ruling. Gated on the
	# tree pause and the Game's load screen visibility, NOT on
	# LoadScene.loading: that flag is only cleared on the mouse-click reveal
	# path, so it can stay true forever on programmatic reveals (observed live
	# on the first floor), which would disable the whole room-purpose lane.
	if get_tree().paused:
		return
	var screen := game.load_screen
	if screen != null and screen.visible:
		return
	if game.current_floor_level == Game.LOWEST_FLOOR_LEVEL:
		return   # floor -5: scripted shard-chanting lane, no room-purpose ambience
	var level : GameWorld = game.level
	if level == null or not is_instance_valid(level) or level.world_data == null:
		return
	var player = game.player
	if player == null or not is_instance_valid(player):
		return

	var room := _room_at_position(level, player.global_position)
	var stream : AudioStream = EMPTY_AMBIENCE
	if room != null:
		var step := level.world_generator.get_node_or_null("GenerateRoomPurposes")
		if step != null:
			var purpose := _get_purpose_for_room_type(step, room.type)
			if purpose != null and purpose.ambient_stream != null:
				stream = purpose.ambient_stream
	LoadScene.play_ambient(stream, 0.0)


## The player's world position decides the room: the existing code resolves
## the room of a cell through the META_ROOM_DATA cell meta that
## WorldData.fill_room_data stamps on every room cell (see generate_doors.gd,
## world_navigation.gd). Returns null for corridor and unknown cells.
func _room_at_position(level : GameWorld, world_pos : Vector3) -> RoomData:
	var local_pos := world_pos - level.global_position
	var cell_index : int = level.world_data.get_cell_index_from_local_position(local_pos)
	return level.world_data.get_cell_meta(
			cell_index, WorldData.CellMetaKeys.META_ROOM_DATA) as RoomData


## Data-level room query: cell index plus the GenerateRoomPurposes step node
## (the RoomPurpose resources live on it). Split from the position wrapper so
## tests and probes can drive crafted WorldData directly.
func _resolve_room_ambient_stream_for_data(world_data : WorldData, p_cell_index : int,
		purpose_step : Node) -> AudioStream:
	var room := world_data.get_cell_meta(
			p_cell_index, WorldData.CellMetaKeys.META_ROOM_DATA) as RoomData
	if room == null or purpose_step == null:
		return null
	var purpose := _get_purpose_for_room_type(purpose_step, room.type)
	if purpose == null:
		return null
	return purpose.ambient_stream   # null allowed: purpose with no track yet


## RoomPurpose resources live on the level's GenerateRoomPurposes generation
## step; purpose_id is stored as a string ("1") that names a
## RoomData.OriginalPurpose index, so compare stringified.
func _get_purpose_for_room_type(purpose_step : Node, p_room_type : int) -> RoomPurpose:
	for value in purpose_step.purpose_resources:
		var purpose := value as RoomPurpose
		if purpose != null and str(purpose.purpose_id) == str(p_room_type):
			return purpose
	return null

### -----------------------------------------------------------------------------------------------

### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
