extends Object
class_name AttackTypes

enum Types {
	PHYSICAL,
	SPECIAL,
	TYPE_COUNT, # Not a type, helper value for the ammount of types
}

func _init():
	printerr("The ", get_class(), " class is used only for global constants and should not be instantiated")
	self.free()
