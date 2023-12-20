class_name BTRoot extends BTSequence


onready var character: Character = owner


# TODO: maybe multithread this. - Alek
func _process(_delta: float) -> void:
	._tick(character.character_state, self)


# Delete mind, cancelling further planning and speech.
func _on_character_died() -> void:
	queue_free()
