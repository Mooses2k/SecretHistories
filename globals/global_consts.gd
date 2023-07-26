class_name GlobalConsts
extends Object


# Keeping enums/conts on a centralized location helps prevent cyclic
# reference errors

enum _AttackTypes {
	BLUDGEONING, # Blunt
	SLASHING,
	PIERCING,
	BALLISTIC,
	FIRE,
	SPECIAL,
	_COUNT, # Not a type, helper value for the ammount of types
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
	DAMAGING,
	INVENTORY,
	EQUIPPED,
	BUSY
}
