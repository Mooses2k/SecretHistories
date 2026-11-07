# Pins the SettingsConfig save coalescing (globals/settings_config.gd).
# The boot restore fan-out used to write the same dictionary 12 times back to
# back: every restored value went through a settings autoload property setter,
# each setter emitted setting_changed, and every listener called
# save_settings() again. Now save_settings() only marks a batch pending, the
# one-shot timer writes the settled batch once, and tree exit flushes a
# pending batch. Pinned here:
#   1. repeated save requests inside the debounce window produce a single
#      disk write,
#   2. a settled value change still reaches the file with its new value,
#   3. a pending request is flushed on tree exit, so quitting right after a
#      change cannot lose it,
#   4. each settled batch after the first writes exactly once more.
# The subject is a fresh instance of the autoload script with both file paths
# redirected into user://tests/tmp, so the suite never touches the real user
# settings file. Write counting reads the subject's _write_count telemetry;
# persistence truth is read back from disk with the same str_to_var the
# loader uses.
extends GutTest

const SETTINGS_SCRIPT := "res://globals/settings_config.gd"
const TEST_DIR := "user://tests/tmp/settings_save_debounce"
const TEST_FILE := TEST_DIR + "/settings_config.dict"

var subject : Node
var _first_run_before : bool


func before_each() -> void:
	_first_run_before = GameSettings.is_first_run
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	DirAccess.remove_absolute(TEST_FILE)
	subject = load(SETTINGS_SCRIPT).new()
	subject.file_name = TEST_FILE
	subject.file_name_default = TEST_DIR + "/default_settings.dict"
	add_child_autofree(subject)
	# Settle the no-file bootstrap save so every test measures from zero.
	subject._flush_pending_save()
	subject._write_count = 0


func after_each() -> void:
	GameSettings.is_first_run = _first_run_before


func _read_saved_dict() -> Dictionary:
	var file = FileAccess.open(TEST_FILE, FileAccess.READ)
	assert_true(file != null, "the settings file must exist on disk after the flush")
	if file == null:
		return {}
	var data = str_to_var(file.get_as_text())
	file.close()
	if data is Dictionary:
		return data
	assert_true(false, "the settings file must parse back to a dictionary")
	return {}


func test_repeated_saves_in_window_settle_into_one_disk_write() -> void:
	for _i in 5:
		subject.save_settings()
	assert_eq(subject._write_count, 0, "no disk write while the debounce window is open")

	await get_tree().create_timer(0.5).timeout

	assert_eq(subject._write_count, 1, "the whole batch must settle into a single disk write")
	var data : Dictionary = _read_saved_dict()
	assert_true(data.has("is_crouch_hold"), "the settled write must carry the tracked settings")
	assert_true(data.has("is_first_run"), "the settled write must carry is_first_run")


func test_value_change_still_persists_after_flush() -> void:
	GameSettings.is_first_run = not GameSettings.is_first_run
	subject.save_settings()

	await get_tree().create_timer(0.5).timeout

	var data : Dictionary = _read_saved_dict()
	assert_eq(str(data.get("is_first_run", "MISSING")), "bool(%s)" % str(GameSettings.is_first_run),
		"the flushed file must carry the changed value")


func test_exit_flush_persists_a_pending_save() -> void:
	GameSettings.is_first_run = false
	subject.save_settings()
	assert_eq(subject._write_count, 0, "the request is still pending before exit")

	remove_child(subject)  # the same _exit_tree path an app quit takes

	assert_eq(subject._write_count, 1, "leaving the tree must flush the pending batch")
	var data : Dictionary = _read_saved_dict()
	assert_eq(str(data.get("is_first_run", "MISSING")), "bool(false)",
		"the exit flush must persist the pending value")


func test_each_settled_batch_after_the_first_writes_again() -> void:
	subject.save_settings()
	await get_tree().create_timer(0.5).timeout
	subject.save_settings()

	await get_tree().create_timer(0.5).timeout

	assert_eq(subject._write_count, 2, "each settled batch must write exactly once")
