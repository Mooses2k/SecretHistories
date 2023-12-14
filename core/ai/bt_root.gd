class_name BTRoot extends BTSelector


onready var character: Character = owner


# TODO: maybe multithread this. - Alek
func _process(_delta: float) -> void:
	.tick(character.character_state)


# Delete mind, cancelling further planning and speech.
func _on_character_died() -> void:
	queue_free()
