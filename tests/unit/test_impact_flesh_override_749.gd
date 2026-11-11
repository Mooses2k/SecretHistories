extends GutTest

## Pins the impact-audio material override for issue #749 (3.x parity,
## origin/main scenes/objects/pickable_items/pickable_item.gd play_drop_sound
## Cultist branch: an item landing on a cultist body played the flesh impact
## stream, blade_to_flesh.wav, instead of the item's own drop sound). Dev4's
## item audio manager resolves the same rule from the strongest impact
## contact: a non-player character body selects the flesh stream, the player
## body and world geometry keep the item's own drop sound.

const ITEM_SCENE := "res://scenes/objects/pickable_items/_pickable_item.tscn"
const CULTIST_SCENE := "res://scenes/characters/cultist/neophyte.tscn"
const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const FLESH_STREAM := "res://resources/sounds/impacts/blade_to_flesh/blade_to_flesh.wav"
const METAL_STREAM := "res://resources/sounds/impacts/metal_and_gun/414848__link-boy__metal-bang.wav"


func _boot_item() -> PickableItem:
	var item : PickableItem = (load(ITEM_SCENE) as PackedScene).instantiate()
	add_child_autofree(item)
	item.item_drop_sound = load(METAL_STREAM)
	# _configure_audio_manager is deferred from _ready; run it now so the
	# manager carries the item's own drop sound deterministically.
	item._configure_audio_manager()
	item.impact_audio_manager.is_soundplayer_ready = true
	return item


func _strongest_stream(item : PickableItem) -> AudioStream:
	var found : AudioStream = null
	for child in item.get_children():
		if child is AudioStreamPlayer3D and (child as AudioStreamPlayer3D).stream != null:
			found = (child as AudioStreamPlayer3D).stream
	return found


func test_impact_on_a_cultist_body_plays_the_flesh_stream() -> void:
	var item := _boot_item()
	var cultist : Node = (load(CULTIST_SCENE) as PackedScene).instantiate()
	add_child_autofree(cultist)

	item.impact_audio_manager.play_impact_sound(5.0, cultist)

	assert_eq(_strongest_stream(item), load(FLESH_STREAM),
			"an impact on a cultist body selects the flesh stream")


func test_impact_on_the_player_body_keeps_the_item_drop_sound() -> void:
	var item := _boot_item()
	var player : HumanoidCharacter = (load(PLAYER_SCENE) as PackedScene).instantiate()
	add_child_autofree(player)

	item.impact_audio_manager.play_impact_sound(5.0, player)

	assert_eq(_strongest_stream(item), load(METAL_STREAM),
			"the player body is excluded exactly as the 3.x name check excluded it")


func test_impact_on_world_geometry_keeps_the_item_drop_sound() -> void:
	var item := _boot_item()
	var floor_body : StaticBody3D = StaticBody3D.new()
	add_child_autofree(floor_body)

	item.impact_audio_manager.play_impact_sound(5.0, floor_body)

	assert_eq(_strongest_stream(item), load(METAL_STREAM),
			"a plain world contact keeps the item's own drop sound")
