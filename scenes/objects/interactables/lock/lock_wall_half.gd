extends Interactable

signal lock_locked()
signal lock_unlocked()

export var _door_half : NodePath
onready var other_half = get_node(_door_half) if not other_half else other_half

var is_locked : bool = false setget set_locked

func _ready():
	other_half.connect("padlock_unlocked", self, "on_padlock_unlocked")

func on_padlock_unlocked():
	if self.is_locked:
		self.is_locked = false

func set_locked(value : bool):
	if is_locked != value:
		is_locked = value
		if is_locked:
			emit_signal("lock_locked")
			$AnimationPlayer.play("lock")
			owner.door_lock_count += 1
		else:
			emit_signal("lock_unlocked")
			$AnimationPlayer.play_backwards("lock")
			owner.door_lock_count -= 1


func _interact(character):
	# Unlock Attempt
	if is_locked:
		other_half._interact(character)
	else:
		# The order matters, since try_lock_padlock will lock the padlock 
		# as soon as it's called
		if owner.can_lock() and other_half.try_lock_padlock():
			self.is_locked = true
	pass
