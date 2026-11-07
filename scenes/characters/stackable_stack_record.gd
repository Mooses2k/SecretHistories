class_name StackableStackRecord
extends Resource

## One stack owned by an Inventory: how many units of one StackableResource
## type the player owns, independent of any world node. The Inventory creates,
## mutates and destroys records through its stack record API; item scripts call
## that API and never touch record internals. Records store no node references:
## the hotbar's representative EquipmentItem links back with stack_record_id.

## Stable id, unique within the owning Inventory, persisted by the save system.
var id: int = -1

## Identity of the stack type: the res:// path of the StackableResource.
var type_id: StringName = &""

## res:// path of the representative item scene, used to materialize nodes.
var item_scene_path: String = ""

## How many units of this item the inventory owns.
var count: int = 0

## State carried for the stack, e.g. {"charges_held": n} for medical
## containers. Empty when the type carries no per-item state.
var per_item_state: Dictionary = {}
