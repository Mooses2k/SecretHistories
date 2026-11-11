#extended only for class_name reasons
extends HumanoidCharacter
class_name Player


## The belt hook attach point (3.x scenes/characters/character.tscn:160
## BeltPosition, same translation): a stowed can_attach lantern parents here
## and keeps burning. Rigs without the marker leave this null, which keeps
## Inventory.attach_to_belt a safe no-op on NPCs and the bare humanoid.
@onready var belt_position: Marker3D = get_node_or_null("BeltPosition") as Marker3D
