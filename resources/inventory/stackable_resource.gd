extends Resource
## This resource represents a stackable EquipementItem[br]
## To use it, just create a resource of type StackableResource, define the properties and attach on each scene/equipment you want to stack
class_name StackableResource


## The type identity of a stack: its own res:// path. The per-record state
## (count, representative, per-item data) lives in Inventory's
## StackableStackRecord, not here; this resource stays a pure type definition.
## The old per-node items_stacked array was deleted with the legacy stack
## model (S2).
@export var stack_name: String

## The max items this stack can hold
@export var max_stack: int
