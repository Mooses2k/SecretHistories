## Test script list for tests/run_gut_chunk_kick.gd; private kick lane chunk.
## Kick suites: the #606 kick trigger pins plus the #747 kick feedback pins.
const SCRIPTS: Array[String] = [
	"res://tests/unit/test_shift_overload_606.gd",
	"res://tests/unit/test_separate_bindable_triggers_606.gd",
	"res://tests/unit/test_kick_feedback_747.gd",
]
