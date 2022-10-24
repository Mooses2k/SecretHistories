extends Object
class_name GlobalConsts


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
