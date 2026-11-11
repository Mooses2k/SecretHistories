## Test script list for tests/run_gut_chunk_phase3.gd; rewritten per chunk
## run. Shell insertion lane: the new Phase 3 suite plus the reload
## lifecycle and ejection suites as regression canaries (the insertion beat
## hooks the same landed-round path those suites pin).
const SCRIPTS: Array[String] = [
	"res://tests/unit/test_shell_insertion.gd",
	"res://tests/unit/test_shell_ejection.gd",
	"res://tests/unit/test_reload_stage_abort.gd",
	"res://tests/unit/test_reload_weapon_anim.gd",
	"res://tests/unit/test_reload_character_anim.gd",
]
