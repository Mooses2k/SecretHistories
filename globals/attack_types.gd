class_name AttackTypes
extends Object


enum Types {
	BLUDGEONING,   # Blunt
	SLASHING,
	PIERCING,
	BALLISTIC,   # Bullets
	FIRE,
	SPECIAL,
	_COUNT,   # Not a type, helper value for the amount of types
}


func _init():
	printerr("The ", get_class(), " class is used only for global constants and should not be instantiated")
	self.free()
