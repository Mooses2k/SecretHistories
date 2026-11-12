## Test script list for tests/run_gut_chunk_lfix.gd; private to the L
## screen-filter fix lane to avoid the shared gut_chunk_list.gd clobber race.
const SCRIPTS: Array[String] = [
	"res://tests/unit/test_screen_filter_cycle.gd",
	"res://tests/unit/test_debug_light_toggle.gd",
	"res://tests/unit/test_screen_filter_registration.gd",
]
