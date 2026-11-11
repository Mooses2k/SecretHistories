## Test script list for tests/run_gut_chunk_inv.gd; rewritten per chunk run.
## Inventory fix lane: the can_attach re-equip invariant suite plus the
## inventory/holster/hold positions/ammo readout regression suites.
const SCRIPTS: Array[String] = [
	"res://tests/unit/test_can_attach_reequip.gd",
	"res://tests/unit/test_reload_character_anim.gd",
	"res://tests/unit/test_light_slot_fallthrough.gd",
	"res://tests/unit/test_search_hotbar_matched.gd",
	"res://tests/unit/test_medical_consolidation.gd",
	"res://tests/unit/test_offhand_use_without_mainhand.gd",
	"res://tests/unit/test_hold_positions.gd",
	"res://tests/unit/test_ammo_readout.gd",
	"res://tests/unit/test_save_inventory_capture.gd",
]
