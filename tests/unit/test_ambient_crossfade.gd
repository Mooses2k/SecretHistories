extends GutTest

# Manager-level pins for the ambience crossfade engine on the BackgroundMusic
# autoload scene (issue #179, music half). Subject:
# res://scenes/effects/background_music.gd via its scene.
#
# Pinned here: identity continuity (no restart on same track, intact through
# the crossfade entry point), crossfade start with two players and commit to a
# single active player, hysteresis (no retrigger mid-fade), doorway-thrash
# reversal without cutting the outgoing track, null-track (fountain) fallback,
# room-of-cell resolution, and loop enforcement on mp3 streams.
# Not pinned (engine audio minutiae): exact db curves, bus meters.

const MANAGER_SCENE := "res://scenes/effects/background_music.tscn"
const PURPOSE_STEP_SCRIPT := "res://scenes/worlds/world_gen/generation_steps/generate_room_purposes.gd"
const CRYPT_PURPOSE := "res://scenes/worlds/world_gen/helper_objects/room_purposes/crypt.tres"
const FOUNTAIN_PURPOSE := "res://scenes/worlds/world_gen/helper_objects/room_purposes/fountain_room.tres"

var EMPTY_AMBIENCE : AudioStream = preload("res://resources/sounds/music/ambience_empty_(mastered).ogg")
var CRYPT_AMBIENCE : AudioStream = preload("res://resources/sounds/music/cryptsMASTER.mp3")
var STATUE_AMBIENCE : AudioStream = preload("res://resources/sounds/music/statueMASTER2.mp3")

var manager : AudioStreamPlayer


func before_each() -> void:
	manager = (load(MANAGER_SCENE) as PackedScene).instantiate()
	add_child_autofree(manager)
	manager.stop()
	manager.stream = null
	manager.volume_db = 0.0


func after_each() -> void:
	manager.stop()
	manager.stream = null
	if manager._crossfade_player != null:
		manager._crossfade_player.stop()
		manager._crossfade_player.stream = null


func _frames(count : int) -> void:
	for _i in count:
		await get_tree().process_frame


#--- identity continuity --------------------------------------------------------------------------

func test_same_stream_request_continues_without_restart() -> void:
	manager.play_ambient(EMPTY_AMBIENCE, 0.0)
	await _frames(2)
	assert_true(manager.playing, "first request starts the track")
	# let the initial fade-in from the stopped player finish before the identity pin
	await get_tree().create_timer(3.4).timeout
	await get_tree().create_timer(0.5).timeout
	var pos_before : float = manager.get_playback_position()
	assert_gt(pos_before, 0.0, "playback position was advancing before the request")

	manager.play_ambient(EMPTY_AMBIENCE, 0.0)
	await _frames(2)
	var pos_after : float = manager.get_playback_position()

	assert_true(manager.playing, "same-stream request keeps the track playing")
	assert_eq(manager.stream, EMPTY_AMBIENCE, "stream unchanged")
	assert_true(pos_after >= pos_before, "playback position not reset (before=%s after=%s)"
			% [pos_before, pos_after])
	assert_false(manager._fade_active, "same-stream request starts no crossfade")
	assert_false(manager._crossfade_player.playing, "crossfade player stays idle")


func test_null_stream_request_is_a_noop() -> void:
	manager.play_ambient(EMPTY_AMBIENCE, 0.0)
	await _frames(2)
	manager.play_ambient(null, 0.0)
	await _frames(2)
	assert_true(manager.playing, "null request does not stop the track")
	assert_eq(manager.stream, EMPTY_AMBIENCE, "null request does not switch the track")


#--- crossfade engine -----------------------------------------------------------------------------

func test_crossfade_runs_two_players_then_commits_to_single_active_player() -> void:
	manager.play_ambient(EMPTY_AMBIENCE, 0.0)
	await _frames(2)
	manager.play_ambient(CRYPT_AMBIENCE, 0.0)
	await _frames(2)

	assert_true(manager._fade_active, "crossfade marked active")
	assert_true(manager.playing, "outgoing player still active during crossfade")
	assert_true(manager._crossfade_player.playing, "incoming player active during crossfade")
	assert_eq(manager._crossfade_player.stream, CRYPT_AMBIENCE, "incoming player carries the new stream")

	await get_tree().create_timer(3.4).timeout

	assert_false(manager._fade_active, "crossfade completed")
	assert_false(manager._crossfade_player.playing, "incoming player went idle after commit")
	assert_eq(manager._crossfade_player.stream, null, "incoming player stream cleared")
	assert_eq(manager.stream, CRYPT_AMBIENCE, "root player adopted the new stream")
	assert_true(manager.playing, "exactly one active player remains, playing the new track")


func test_crossfade_hysteresis_does_not_retrigger_same_target() -> void:
	manager.play_ambient(EMPTY_AMBIENCE, 0.0)
	await _frames(2)
	manager.play_ambient(CRYPT_AMBIENCE, 0.0)
	await get_tree().create_timer(0.5).timeout
	var child_pos_before : float = manager._crossfade_player.get_playback_position()

	manager.play_ambient(CRYPT_AMBIENCE, 0.0)
	await _frames(2)

	assert_true(manager._fade_active, "transition still the original one")
	assert_true(manager._crossfade_player.playing, "incoming player not restarted")
	assert_true(manager._crossfade_player.get_playback_position() >= child_pos_before,
			"incoming playback position not reset by re-request (before=%s after=%s)"
			% [child_pos_before, manager._crossfade_player.get_playback_position()])
	assert_eq(manager._crossfade_player.stream, CRYPT_AMBIENCE, "same incoming stream")


func test_doorway_thrash_reverses_back_without_cutting_the_outgoing_track() -> void:
	manager.play_ambient(EMPTY_AMBIENCE, 0.0)
	await get_tree().create_timer(0.6).timeout
	var empty_pos_before := manager.get_playback_position()

	manager.play_ambient(CRYPT_AMBIENCE, 0.0)
	await _frames(2)
	manager.play_ambient(EMPTY_AMBIENCE, 0.0)
	await _frames(2)

	assert_eq(manager._target_stream, EMPTY_AMBIENCE, "target flipped back to Empty")
	assert_eq(manager.stream, EMPTY_AMBIENCE, "Empty still on the root player (no adopt cut)")
	assert_true(manager.playing, "Empty kept playing through the reversal")
	assert_true(manager.get_playback_position() >= empty_pos_before,
			"Empty playback position never skipped (before=%s after=%s)"
			% [empty_pos_before, manager.get_playback_position()])

	await get_tree().create_timer(3.4).timeout

	assert_false(manager._fade_active, "reversed crossfade completed")
	assert_eq(manager.stream, EMPTY_AMBIENCE, "Empty is the committed track")
	assert_false(manager._crossfade_player.playing, "crypt incoming player went idle")


func test_rapid_alternation_retargets_in_flight_fade_without_gain_jump() -> void:
	# Enter/leave thrash faster than the crossfade: Empty -> crypt (crossfade
	# starts) -> Empty (reversal toward the root's stream) -> crypt again
	# before the reversal commits. The in-flight fade must retarget smoothly
	# toward the child's stream: no adopt cut, no gain jump on either player,
	# and the fade completes into the last requested track.
	manager.play_ambient(EMPTY_AMBIENCE, 0.0)
	await _frames(2)
	manager.play_ambient(CRYPT_AMBIENCE, 0.0)
	await get_tree().create_timer(0.5).timeout
	manager.play_ambient(EMPTY_AMBIENCE, 0.0)
	await get_tree().create_timer(0.5).timeout
	var root_lin_before : float = db_to_linear(manager.volume_db)
	var child_lin_before : float = db_to_linear(manager._crossfade_player.volume_db)

	manager.play_ambient(CRYPT_AMBIENCE, 0.0)
	await _frames(2)

	var root_lin_after : float = db_to_linear(manager.volume_db)
	var child_lin_after : float = db_to_linear(manager._crossfade_player.volume_db)
	assert_almost_eq(root_lin_after, root_lin_before, 0.15,
			"no gain jump on the outgoing player (before=%s after=%s)"
			% [root_lin_before, root_lin_after])
	assert_almost_eq(child_lin_after, child_lin_before, 0.15,
			"no gain jump on the incoming player (before=%s after=%s)"
			% [child_lin_before, child_lin_after])
	assert_eq(manager._target_stream, CRYPT_AMBIENCE, "target flipped back to crypt")
	assert_eq(manager.stream, EMPTY_AMBIENCE, "no adopt cut: Empty still on the root")
	assert_eq(manager._crossfade_player.stream, CRYPT_AMBIENCE,
			"in-flight child stream preserved, not restarted")

	await get_tree().create_timer(3.4).timeout

	assert_false(manager._fade_active, "retargeted crossfade completed")
	assert_eq(manager.stream, CRYPT_AMBIENCE, "crypt is the committed track")
	assert_false(manager._crossfade_player.playing, "child idle after commit")


#--- loop enforcement -----------------------------------------------------------------------------

func test_mp3_stream_is_forced_to_loop_on_request() -> void:
	CRYPT_AMBIENCE.loop = false   # import default; the manager must enforce looping
	manager.play_ambient(CRYPT_AMBIENCE, 0.0)
	await _frames(2)
	assert_true(CRYPT_AMBIENCE.loop, "mp3 ambience stream loops after request")


#--- owner rulings from the live pass -------------------------------------------------------------

func test_incoming_enters_at_same_relative_point_as_outgoing() -> void:
	manager.play_ambient(EMPTY_AMBIENCE, 0.0)
	await get_tree().create_timer(2.0).timeout   # advance the outgoing well into its length
	var out_pos : float = manager.get_playback_position()
	var out_len : float = EMPTY_AMBIENCE.get_length()
	var in_len : float = CRYPT_AMBIENCE.get_length()
	var expected : float = clampf(out_pos / out_len, 0.0, 1.0) * in_len
	if expected < 0.5:
		await get_tree().create_timer(2.0).timeout   # keep the transfer point unambiguous
		out_pos = manager.get_playback_position()
		expected = clampf(out_pos / out_len, 0.0, 1.0) * in_len
	manager.play_ambient(CRYPT_AMBIENCE, 0.0)
	await _frames(2)
	var start_pos : float = manager._crossfade_player.get_playback_position()
	assert_almost_eq(start_pos, expected, 0.5,
			"incoming entered at the outgoing's relative point (start=%s expected=%s)" % [start_pos, expected])


func test_degenerate_relative_transfer_starts_at_zero() -> void:
	# no outgoing stream: the transfer point is 0 (fresh-track case)
	manager.stream = null
	assert_eq(manager._relative_transfer_position(CRYPT_AMBIENCE), 0.0,
			"no outgoing track: incoming enters at 0")


func test_relative_transfer_maps_progress_onto_incoming_length() -> void:
	manager.stream = EMPTY_AMBIENCE
	manager.play()
	manager.seek(EMPTY_AMBIENCE.get_length() * 0.5)
	await _frames(2)
	var mapped : float = manager._relative_transfer_position(CRYPT_AMBIENCE)
	var expected : float = EMPTY_AMBIENCE.get_length() * 0.5 \
			/ EMPTY_AMBIENCE.get_length() * CRYPT_AMBIENCE.get_length()
	assert_almost_eq(mapped, CRYPT_AMBIENCE.get_length() * 0.5, 0.2,
			"halfway outgoing maps to halfway incoming (got %s)" % str(mapped))


func test_crossfade_is_simultaneous_equal_gain_not_out_then_in() -> void:
	manager.play_ambient(EMPTY_AMBIENCE, 0.0)
	# settle the fade-in first so the crossfade starts from the steady state
	# the production poller sees (a crossfade starting from a mid-fade-in
	# silence is legal but not the shape this test pins)
	await get_tree().create_timer(3.2).timeout
	manager.play_ambient(CRYPT_AMBIENCE, 0.0)
	# mid-fade sample: both players must be moving at the same time and their
	# amplitude-domain gains must sum to the target gain (linear equal-gain:
	# no dB-domain midpoint dip, no sequential fade-out-then-fade-in)
	await get_tree().create_timer(1.5).timeout
	var root_lin : float = db_to_linear(manager.volume_db)
	var child_lin : float = db_to_linear(manager._crossfade_player.volume_db)
	assert_gt(root_lin, 0.0, "outgoing still audible at midpoint (never hard-stopped)")
	assert_gt(child_lin, 0.0, "incoming already audible at midpoint")
	assert_almost_eq(root_lin + child_lin, 1.0, 0.06,
			"equal-gain overlap at midpoint (root=%s child=%s)" % [root_lin, child_lin])
	assert_true(manager.playing and manager._crossfade_player.playing,
			"both players active at midpoint")


#--- room-of-cell resolution ----------------------------------------------------------------------

func test_room_resolution_maps_crypt_null_track_and_no_room() -> void:
	var world_data := WorldData.new()
	world_data.resize(8, 8)
	# crypt room cells 1..3 x 1..3, fountain room cells 5..6 x 1..2
	world_data.fill_room_data(Rect2(1, 1, 3, 3), WorldData.OriginalPurpose.CRYPT)
	world_data.fill_room_data(Rect2(5, 1, 2, 2), WorldData.OriginalPurpose.FOUNTAIN)

	var step := Node.new()
	step.set_script(load(PURPOSE_STEP_SCRIPT))
	step.purpose_resources = [load(CRYPT_PURPOSE), load(FOUNTAIN_PURPOSE)]
	add_child_autofree(step)

	var crypt_cell : int = world_data.get_cell_index_from_int_position(2, 2)
	var fountain_cell : int = world_data.get_cell_index_from_int_position(5, 1)
	var corridor_cell : int = world_data.get_cell_index_from_int_position(7, 7)

	var crypt_stream : AudioStream = manager._resolve_room_ambient_stream_for_data(world_data, crypt_cell, step)
	var fountain_stream : AudioStream = manager._resolve_room_ambient_stream_for_data(world_data, fountain_cell, step)
	var corridor_stream : AudioStream = manager._resolve_room_ambient_stream_for_data(world_data, corridor_cell, step)

	assert_eq(crypt_stream, CRYPT_AMBIENCE, "crypt room resolves to its purpose track")
	assert_eq(fountain_stream, null, "fountain room has no track yet: null falls back to Empty upstream")
	assert_eq(corridor_stream, null, "cell without a room resolves to no own track (Empty)")


func test_room_resolution_matches_string_purpose_ids() -> void:
	var world_data := WorldData.new()
	world_data.resize(8, 8)
	world_data.fill_room_data(Rect2(1, 1, 3, 3), WorldData.OriginalPurpose.STATUE_GALLERY)

	var step := Node.new()
	step.set_script(load(PURPOSE_STEP_SCRIPT))
	step.purpose_resources = [load("res://scenes/worlds/world_gen/helper_objects/room_purposes/statue_gallery.tres")]
	add_child_autofree(step)

	var gallery_cell : int = world_data.get_cell_index_from_int_position(1, 1)
	var stream : AudioStream = manager._resolve_room_ambient_stream_for_data(world_data, gallery_cell, step)
	assert_eq(stream, STATUE_AMBIENCE,
			"statue gallery purpose_id string matches the OriginalPurpose int")
