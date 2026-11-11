## Test script list for tests/run_gut_chunk_ai_p1.gd; rewritten per chunk run.
## AI HFSM Phase 1 lane (cultist cutover): the new live-brain suites, the
## repointed hearing wiring, the save compat pin, the phase 0 framework
## suites as regression canaries, and the perception suites.
const SCRIPTS: Array[String] = [
	"res://tests/unit/test_cultist_brain_wiring.gd",
	"res://tests/unit/test_animation_bridge_audio.gd",
	"res://tests/unit/test_cultist_hearing_wiring.gd",
	"res://tests/unit/test_ai_save_compat.gd",
	"res://tests/unit/test_hfsm_runner.gd",
	"res://tests/unit/test_threat_model.gd",
	"res://tests/unit/test_cultist_states.gd",
	"res://tests/unit/test_sound_sensor_interest.gd",
	"res://tests/unit/test_noise_propagation.gd",
	"res://tests/unit/test_movement_noise_ladder.gd",
	"res://tests/unit/test_gunshot_noise.gd",
]
