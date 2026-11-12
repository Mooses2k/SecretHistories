## Test script list for tests/run_gut_chunk_aifix.gd; rewritten per chunk run.
## AI-defects lane: the live sensor-chain suite for the playtest defects
## (c)(d)(e), the existing brain/hearing/audio/save/state suites as
## regression canaries, and the issue 749 death-drop canary.
const SCRIPTS: Array[String] = [
	"res://tests/unit/test_cultist_scene_sensors.gd",
	"res://tests/unit/test_cultist_brain_wiring.gd",
	"res://tests/unit/test_cultist_hearing_wiring.gd",
	"res://tests/unit/test_animation_bridge_audio.gd",
	"res://tests/unit/test_ai_save_compat.gd",
	"res://tests/unit/test_cultist_states.gd",
	"res://tests/unit/test_light_level_sight.gd",
	"res://tests/unit/test_cultist_death_drop_749.gd",
]
