extends RefCounted
## Private chunk list for the melee2 lane (item animation wiring + candelabra
## grab area). Do not run from the shared .gutconfig; use
## tests/run_gut_chunk_melee2.gd.

const SCRIPTS := [
	"res://tests/unit/test_melee_attack_parity.gd",
	"res://tests/unit/test_torch_cut.gd",
	"res://tests/unit/test_torch_hold_up.gd",
	"res://tests/unit/test_floor_candelabra_ignite_area.gd",
	"res://tests/unit/test_floor_candelabra_take.gd",
]
