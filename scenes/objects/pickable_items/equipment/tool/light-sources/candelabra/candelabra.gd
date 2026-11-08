class_name CandelabraItem
extends ToolItem
## Multi-candle light container (fuel design owner decisions 5 and 6): each
## candle is a per-candle WAX fuel state burning at the same duration as a
## loose candle (owner ruling: a candelabra's candles ARE candles), and the
## shared light output follows the per-object logarithmic curve with the
## lit-candle count, so a stand with one candle left reads dimmer than a
## fully lit one. Refill rides the medical-reload seam (owner ruling b): one
## tap R fills one spent candle slot to 1.0 by consuming one candle unit
## from a hotbar candle stack; it never auto-lights. Whole-candle socket
## insert/swap interactions arrive with the removable-candle work; inserted
## candles do NOT auto-light.


signal item_dropped

const BURN_SECONDS := 3600.0  # same as candle.gd per owner ruling

@export var number_of_candles : int = 1
## Tuning gain of the per-object light-output curve (FuelContainer.light_scale_for).
@export var light_scale_gain : float = 0.5

var is_lit : bool = false
var is_depleted : bool = false
var random_number : float
@export var life_percentage_lose : float = 0.0 # (float, 0.0, 1.0)
@export var prob_going_out : float = 0.0 # (float, 0.0, 1.0)

var candle_fuel : Array[FuelContainer] = []
var candle_lit : Array[bool] = []

var material : Material
var new_material : Material
var base_light_energy : float = 0.0
var base_light_range : float = 0.0

var firelight: Light3D


func _ready():
	_setup_candle_fuel()
	self.connect("item_dropped", Callable(self, "light_dropped"))
	_setup_base_light()
	_setup_candle_materials()


## Per-candle fuel states are built from number_of_candles alone, so they do
## not depend on the candle child nodes existing (the candlestick and candle
## lantern scenes run this script with one candle).
func _setup_candle_fuel() -> void:
	candle_fuel.clear()
	candle_lit.clear()
	for i in range(number_of_candles):
		var fuel := FuelContainer.new()
		fuel.set_fuel(FuelSource.FuelKind.WAX, BURN_SECONDS)
		candle_fuel.append(fuel)
		candle_lit.append(false)


func _setup_base_light() -> void:
	# Resolved on demand (not @onready) so the per-candle fuel states can be
	# exercised without the heavy scene or a live tree.
	firelight = get_node_or_null("Candle1/FireOrigin/Fire/Light3D")
	if firelight == null:
		return
	base_light_energy = firelight.light_energy
	base_light_range = _light_range(firelight)


func _setup_candle_materials() -> void:
	var candle1_mesh: MeshInstance3D = get_node_or_null("Candle1/MeshInstance3D")
	if candle1_mesh == null:
		return
	material = candle1_mesh.get_surface_override_material(0)
	if material == null:
		return
	new_material = material.duplicate()
	candle1_mesh.set_surface_override_material(0, new_material)
	for i in range(1, number_of_candles):
		var mesh: MeshInstance3D = get_node_or_null("Candle%d/MeshInstance3D" % (i + 1))
		if mesh != null:
			mesh.set_surface_override_material(0, new_material)


func _candle_node(index: int) -> Node:
	return get_node_or_null("Candle%d" % (index + 1))


func _set_candle_fire(index: int, lit: bool) -> void:
	var candle := _candle_node(index)
	if candle == null:
		return
	var fire: Node3D = candle.get_node_or_null("FireOrigin/Fire")
	if fire != null:
		fire.visible = lit
	var mesh: MeshInstance3D = candle.get_node_or_null("MeshInstance3D")
	if mesh != null:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if lit \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mesh_material: Material = mesh.get_surface_override_material(0)
		if mesh_material != null:
			mesh_material.emission_enabled = lit


func _light_range(light: Light3D) -> float:
	if light is OmniLight3D:
		return light.omni_range
	if light is SpotLight3D:
		return light.spot_range
	return 0.0


func _set_light_range(light: Light3D, value: float) -> void:
	if light is OmniLight3D:
		light.omni_range = value
	elif light is SpotLight3D:
		light.spot_range = value


func _process(delta: float) -> void:
	super._process(delta)
	if candle_fuel.is_empty():
		return
	for i in range(candle_fuel.size()):
		if not candle_lit[i]:
			continue
		if candle_fuel[i].tick_burn(delta, true):
			candle_lit[i] = false
			_set_candle_fire(i, false)
			_refresh_light_output()
			if i == 0:
				_on_light_depleted()
				break


func light():
	if is_depleted:
		return
	var anim: AnimationPlayer = get_node_or_null("AnimationPlayer")
	if anim != null:
		anim.play("flicker")
	# The LightSound node is positional in the handheld candelabra scenes
	# (AudioStreamPlayer3D), so type it as Node and duck-type the play call:
	# typing it AudioStreamPlayer crashed the item light-up at spawn
	# (owner report 2026-11-08: crash on entering game after Click to Continue).
	var light_sound: Node = get_node_or_null("LightSound")
	if light_sound != null and light_sound.has_method("play"):
		light_sound.play()

	for i in range(candle_fuel.size()):
		if not candle_fuel[i].can_burn():
			continue
		_set_candle_fire(i, true)
		candle_lit[i] = true

	if firelight != null:
		firelight.visible = true
	var own_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if own_mesh != null:
		own_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	is_lit = true
	_refresh_light_output()


func unlight():
	var anim: AnimationPlayer = get_node_or_null("AnimationPlayer")
	if anim != null:
		anim.stop()
	for i in range(candle_lit.size()):
		_set_candle_fire(i, false)
		candle_lit[i] = false

	if firelight != null:
		firelight.visible = false
	var own_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if own_mesh != null:
		own_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	is_lit = false


func _use_primary():
	if is_lit == false:
		light()
	else:
		unlight()
		$BlowOutSound.play()


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		owner_character.inventory.switch_away_from_light(self)
	elif current_state == GlobalConsts.ItemState.DROPPED:
		# Emit only, and under the DECLARED signal name (Brooks audit 4.4): the
		# old emit of the undeclared "item_is_dropped" silently failed, so the
		# drop penalty for candles 2 and 3 never ran.
		self.emit_signal("item_dropped")


# Connected to the item_dropped signal (fires once per drop)
func light_dropped():
	# Apply the base candle 1 drop penalty too, which the deleted direct
	# item_drop() call used to cover before the emit-only fix
	item_drop()
	for i in range(1, candle_fuel.size()):
		var fuel := candle_fuel[i]
		if fuel.fuel_source == null:
			continue
		fuel.fill -= fuel.fill * life_percentage_lose
		random_number = randf_range(0.0, 1.0)
		if random_number < prob_going_out:
			candle_lit[i] = false
			_set_candle_fire(i, false)
	_refresh_light_output()


func _on_light_depleted():
	unlight()
	is_depleted = true


func item_drop():
	# Drop penalty (3.x life_percentage_lose semantics) applied to the base
	# candle's fuel fill, exactly once per drop.
	if not candle_fuel.is_empty() and candle_fuel[0].fuel_source != null:
		candle_fuel[0].fill -= candle_fuel[0].fill * life_percentage_lose
	random_number = randf_range(0.0, 1.0)

	if linear_velocity.length() > 0.01:
		if random_number < prob_going_out:
			unlight()


func count_lit_candles() -> int:
	var lit := 0
	for state in candle_lit:
		if state:
			lit += 1
	return lit


## Per-object light output (owner decision 6): the shared flame light scales
## its authored energy and range by the logarithmic curve over the current
## lit-candle count, so the output drops as candles burn out or are removed.
func _refresh_light_output() -> void:
	if firelight == null:
		return
	var lit := count_lit_candles()
	if lit <= 0:
		firelight.visible = false
		return
	firelight.visible = true
	var scale := FuelContainer.light_scale_for(lit, light_scale_gain)
	firelight.light_energy = base_light_energy * scale
	_set_light_range(firelight, base_light_range * scale)


func _on_ignite_character_interacted(_character: Variant) -> void:
	_use_primary()


## Hotbar-swap refill (owner ruling b, medical-reload baseline, fuel design
## section 6): one tap fills ONE spent candle slot to a full 1.0 by consuming
## one candle unit from a hotbar candle stack. Never auto-lights: the
## lighting state is untouched, and refilling while lit neither lights nor
## extinguishes. This consumption is the one sanctioned wax consumption: the
## candle unit is not destroyed, it becomes the socket's new fill. A
## burned-out stub (fill 0.0) is not a wax source. Fresh wax clears the
## burned-out lockout, so a depleted candelabra can be lit again.
func _use_reload() -> void:
	if owner_character == null:
		return
	var inv : Inventory = owner_character.inventory
	if inv == null:
		return
	var target_slot := _first_spent_slot()
	if target_slot == -1:
		return
	var carriers : Array = inv.search_hotbar_matched(Callable(self, "_is_scannable_candle"))
	for pair in carriers:
		if _refill_slot_from_candle(pair[0], pair[1], inv, target_slot):
			return


## The lowest-index socket that is not full is the refill target: sockets are
## an ordered set, so the take order is deterministic.
func _first_spent_slot() -> int:
	for i in range(candle_fuel.size()):
		if candle_fuel[i].fill < 1.0:
			return i
	return -1


## A hotbar candle is a wax source when it is a real CandleItem carrying wax
## (fill > 0.0). The kind is structural: candle.gd and this script both
## hard-code FuelSource.FuelKind.WAX, so the pour is wax into wax by
## construction. A candle is NOT a FuelContainer percentage carrier
## (FuelContainer.is_fuel_carrier stays false for it, per owner decision 5);
## whole candle units are the exchange shape here, not percentage fills.
func _is_scannable_candle(item : Object) -> bool:
	if not (item is CandleItem):
		return false
	var fuel : FuelContainer = item.get("fuel")
	if fuel == null or fuel.fuel_source == null:
		return false
	if fuel.fuel_source.fuel_kind != FuelSource.FuelKind.WAX:
		return false
	return fuel.fill > 0.0


## One candle unit becomes one full socket. The record is decremented when
## the candle represents a stack (the node stays as the record's
## representative); on its last unit, or with no record at all, the node
## itself is consumed, exactly like the medical reload seam.
func _refill_slot_from_candle(candle : CandleItem, slot_index : int, inv : Inventory, target_slot : int) -> bool:
	var record : StackableStackRecord = null
	if candle.stack_record_id >= 0:
		record = inv.get_stack_record(candle.stack_record_id)
	if record != null and record.count <= 0:
		return false

	candle_fuel[target_slot].fill = 1.0
	is_depleted = false
	if record != null and record.count > 1:
		inv.remove_from_stack_record(record.id, 1)
		inv.emit_signal("hotbar_changed", slot_index)
	else:
		inv.hotbar[slot_index] = null
		if inv.current_mainhand_slot == slot_index:
			inv.unequip_mainhand_item()
		elif inv.current_offhand_slot == slot_index:
			inv.unequip_offhand_item()
		if record != null:
			inv.remove_from_stack_record(record.id, 1)
		inv.emit_signal("hotbar_changed", slot_index)
		candle.queue_free()
	inv.emit_signal("inventory_changed")
	emit_signal("item_data_changed")
	return true
