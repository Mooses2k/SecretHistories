class_name GlobalConsts
extends Object


# Keeping enums/consts in a centralized location helps prevent cyclic
# reference errors

enum AttackTypes {
	BLUDGEONING, # Blunt
	SLASHING,
	PIERCING,
	BALLISTIC,
	FIRE,
	SPECIAL,
}

# Tiny items - ammo, keys - unlimited number carryable
# Small items - equippable, takes a slot, no encumbrance, some can stack
# Medium items - equippable, takes a slot, encumbers per medium item
# Bulky items - equippable in special slot, always two-hands, encumbers as medium item
# Large items - furniture etc, not equippable, grab and drag only
enum ItemSize {
	SIZE_SMALL,
	SIZE_MEDIUM,
	SIZE_BULKY
}

enum ItemState {
	DROPPED,
	INVENTORY,
	EQUIPPED,
	BUSY
}
