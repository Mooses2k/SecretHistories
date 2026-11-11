## Test script list for tests/run_gut_chunk_belt.gd; rewritten per chunk
## run. Belt hook lane: the restored 3.x belt flow suite plus the adjacent
## suites that exercise the touched inventory paths as regression canaries.
## test_reload_character_anim.gd is deliberately excluded: it loads the
## webley, whose .import UIDs are mid-edit by another lane, and it does not
## carry the UID-drift tolerance (known warning-noise env failure).
const SCRIPTS: Array[String] = [
	"res://tests/unit/test_belt_hook.gd",
	"res://tests/unit/test_light_stow_extinguish.gd",
	"res://tests/unit/test_can_attach_reequip.gd",
	"res://tests/unit/test_light_slot_fallthrough.gd",
	"res://tests/unit/test_light_drop_fuel.gd",
	"res://tests/unit/test_save_inventory_capture.gd",
]
