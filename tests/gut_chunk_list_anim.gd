## Test script list for tests/run_gut_chunk_anim.gd; rewritten per chunk run.
## Reload animation lane: the new Phase 1 weapon-side suite plus the reload
## lifecycle suites as regression canaries (their pins were updated to the
## close-beat contract). Private copy so other lanes keep their own lists.
const SCRIPTS: Array[String] = [
	"res://tests/unit/test_reload_weapon_anim.gd",
	"res://tests/unit/test_reload_character_anim.gd",
	"res://tests/unit/test_reload_stage_abort.gd",
	"res://tests/unit/test_shell_ejection.gd",
]
