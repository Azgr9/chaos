# SCRIPT: StatusEffects.gd
# ATTACH TO: Autoload or as component on entities
# LOCATION: res://Scripts/Systems/StatusEffects.gd
# Manages status effects like Burn, Chill, Shock, Bleed

class_name StatusEffects
extends Node

# ============================================
# ENUMS
# ============================================
enum EffectType {
	BURN,    # DoT, stacks intensity
	CHILL,   # Slow, stacks to freeze
	SHOCK,   # Chance to chain damage
	BLEED    # DoT that increases with movement
}

# ============================================
# EFFECT DATA
# ============================================
class StatusEffect:
	var type: EffectType
	var stacks: int = 1
	var duration: float = 0.0
	var tick_timer: float = 0.0
	var source: Node2D = null

	func _init(effect_type: EffectType, dur: float, src: Node2D = null):
		type = effect_type
		duration = dur
		source = src

# ============================================
# CONSTANTS
# ============================================
const BURN_DAMAGE_PER_STACK: float = 3.0
const BURN_TICK_RATE: float = 0.5
const BURN_MAX_STACKS: int = 5
const BURN_DURATION: float = 3.0

const CHILL_SLOW_PER_STACK: float = 0.15  # 15% slow per stack
const CHILL_MAX_STACKS: int = 4  # At 4 stacks = freeze
const CHILL_DURATION: float = 2.5
const FREEZE_DURATION: float = 1.5

const SHOCK_CHAIN_CHANCE: float = 0.3
const SHOCK_CHAIN_RANGE: float = 150.0
const SHOCK_CHAIN_DAMAGE: float = 5.0
const SHOCK_DURATION: float = 2.0

const BLEED_BASE_DAMAGE: float = 2.0
const BLEED_MOVEMENT_MULTIPLIER: float = 0.02  # Per pixel moved
const BLEED_TICK_RATE: float = 0.4
const BLEED_MAX_STACKS: int = 3
const BLEED_DURATION: float = 4.0

# ============================================
# STATE
# ============================================
var target: Node2D = null
var active_effects: Dictionary = {}  # EffectType -> StatusEffect
var is_frozen: bool = false
var base_speed: float = 0.0
var last_position: Vector2 = Vector2.ZERO
var distance_moved: float = 0.0

# Visual nodes
var burn_visual: Node2D = null
var chill_visual: Node2D = null
var shock_visual: Node2D = null
var bleed_visual: Node2D = null

# ============================================
# SIGNALS
# ============================================
signal effect_applied(effect_type: EffectType, stacks: int)
signal effect_removed(effect_type: EffectType)
signal effect_triggered(effect_type: EffectType, damage: float)
signal frozen()
signal unfrozen()

# ============================================
# LIFECYCLE
# ============================================
func _ready():
	target = get_parent()
	if target:
		last_position = target.global_position
		if "move_speed" in target:
			base_speed = target.move_speed

func _process(delta):
	if not target or not is_instance_valid(target):
		return

	# Track movement for bleed
	var current_pos = target.global_position
	distance_moved += current_pos.distance_to(last_position)
	last_position = current_pos

	# Process active effects
	_process_effects(delta)

	# Update visuals
	_update_visuals()

func _process_effects(delta):
	var effects_to_remove: Array[EffectType] = []

	for effect_type in active_effects.keys():
		var effect: StatusEffect = active_effects[effect_type]
		effect.duration -= delta

		if effect.duration <= 0:
			effects_to_remove.append(effect_type)
			continue

		# Process ticks
		effect.tick_timer -= delta
		if effect.tick_timer <= 0:
			_trigger_effect_tick(effect)
			effect.tick_timer = _get_tick_rate(effect_type)

	# Remove expired effects
	for effect_type in effects_to_remove:
		remove_effect(effect_type)

func _trigger_effect_tick(effect: StatusEffect):
	match effect.type:
		EffectType.BURN:
			var burn_damage = BURN_DAMAGE_PER_STACK * effect.stacks
			_deal_effect_damage(burn_damage, EffectType.BURN)
			effect_triggered.emit(EffectType.BURN, burn_damage)

		EffectType.BLEED:
			var bleed_damage = BLEED_BASE_DAMAGE * effect.stacks
			bleed_damage += distance_moved * BLEED_MOVEMENT_MULTIPLIER * effect.stacks
			distance_moved = 0.0  # Reset distance
			_deal_effect_damage(bleed_damage, EffectType.BLEED)
			effect_triggered.emit(EffectType.BLEED, bleed_damage)

		EffectType.SHOCK:
			if randf() < SHOCK_CHAIN_CHANCE:
				_trigger_shock_chain(effect)

func _get_tick_rate(effect_type: EffectType) -> float:
	match effect_type:
		EffectType.BURN: return BURN_TICK_RATE
		EffectType.BLEED: return BLEED_TICK_RATE
		EffectType.SHOCK: return 0.5
		_: return 1.0

# ============================================
# EFFECT APPLICATION
# ============================================
func apply_effect(effect_type: EffectType, source: Node2D = null, stacks: int = 1):
	if is_frozen:
		# Burn can unfreeze frozen targets
		if effect_type == EffectType.BURN:
			_unfreeze()
		else:
			# Other effects don't apply while frozen
			return

	if effect_type in active_effects:
		# Stack existing effect
		var effect = active_effects[effect_type]
		var max_stacks = _get_max_stacks(effect_type)
		effect.stacks = min(effect.stacks + stacks, max_stacks)
		effect.duration = _get_duration(effect_type)  # Refresh duration
		effect.source = source

		# Check for freeze
		if effect_type == EffectType.CHILL and effect.stacks >= CHILL_MAX_STACKS:
			_freeze()
	else:
		# New effect
		var effect = StatusEffect.new(effect_type, _get_duration(effect_type), source)
		effect.stacks = min(stacks, _get_max_stacks(effect_type))
		effect.tick_timer = _get_tick_rate(effect_type)
		active_effects[effect_type] = effect
		_create_effect_visual(effect_type)

	# Apply speed modifier for chill
	if effect_type == EffectType.CHILL:
		_apply_chill_slow()

	effect_applied.emit(effect_type, active_effects[effect_type].stacks)

func remove_effect(effect_type: EffectType):
	if effect_type not in active_effects:
		return

	active_effects.erase(effect_type)
	_remove_effect_visual(effect_type)

	# Restore speed if chill removed
	if effect_type == EffectType.CHILL:
		_remove_chill_slow()

	effect_removed.emit(effect_type)

func clear_all_effects():
	for effect_type in active_effects.keys():
		remove_effect(effect_type)

	if is_frozen:
		_unfreeze()

func has_effect(effect_type: EffectType) -> bool:
	return effect_type in active_effects

func get_stacks(effect_type: EffectType) -> int:
	if effect_type in active_effects:
		return active_effects[effect_type].stacks
	return 0

# ============================================
# EFFECT HELPERS
# ============================================
func _get_max_stacks(effect_type: EffectType) -> int:
	match effect_type:
		EffectType.BURN: return BURN_MAX_STACKS
		EffectType.CHILL: return CHILL_MAX_STACKS
		EffectType.SHOCK: return 1
		EffectType.BLEED: return BLEED_MAX_STACKS
	return 1

func _get_duration(effect_type: EffectType) -> float:
	match effect_type:
		EffectType.BURN: return BURN_DURATION
		EffectType.CHILL: return CHILL_DURATION
		EffectType.SHOCK: return SHOCK_DURATION
		EffectType.BLEED: return BLEED_DURATION
	return 2.0

func _deal_effect_damage(amount: float, effect_type: EffectType):
	if not target or not is_instance_valid(target):
		return

	# Map status effect type to damage type
	var damage_type = _get_damage_type_for_effect(effect_type)

	if target.has_method("take_damage"):
		if target.is_in_group("player"):
			target.take_damage(amount, Vector2.ZERO)
			# Spawn colored damage number for player (player doesn't spawn its own)
			_spawn_effect_damage_number(amount, effect_type)
		else:
			# Pass damage type to enemy so it spawns correctly colored damage number
			target.take_damage(amount, Vector2.ZERO, 0.0, 0.0, null, damage_type)

	# Emit combat event for status effect damage
	if CombatEventBus:
		CombatEventBus.status_triggered.emit(target, effect_type, amount)

func _get_damage_type_for_effect(effect_type: EffectType) -> DamageTypes.Type:
	match effect_type:
		EffectType.BURN:
			return DamageTypes.Type.FIRE
		EffectType.SHOCK:
			return DamageTypes.Type.ELECTRIC
		EffectType.BLEED:
			return DamageTypes.Type.BLEED
		EffectType.CHILL:
			return DamageTypes.Type.ELECTRIC
	return DamageTypes.Type.PHYSICAL

func _spawn_effect_damage_number(amount: float, effect_type: EffectType):
	if not target or not is_instance_valid(target):
		return

	var damage_type = _get_damage_type_for_effect(effect_type)
	if DamageNumberManager:
		DamageNumberManager.spawn(target.global_position, amount, damage_type)

# ============================================
# CHILL / FREEZE
# ============================================
func _apply_chill_slow():
	if not target or is_frozen:
		return

	var effect = active_effects.get(EffectType.CHILL)
	if not effect:
		return

	var slow_amount = CHILL_SLOW_PER_STACK * effect.stacks

	if "move_speed" in target:
		if base_speed == 0:
			base_speed = target.move_speed
		target.move_speed = base_speed * (1.0 - slow_amount)

func _remove_chill_slow():
	if not target:
		return

	if "move_speed" in target and base_speed > 0:
		target.move_speed = base_speed

func _freeze():
	if is_frozen:
		return

	is_frozen = true
	frozen.emit()

	if "move_speed" in target:
		target.move_speed = 0

	# Visual freeze effect
	if target.has_node("VisualsPivot"):
		var visuals = target.get_node("VisualsPivot")
		visuals.modulate = Color(0.5, 0.8, 1.0, 1.0)
	elif target.has_node("Sprite2D"):
		var sprite = target.get_node("Sprite2D")
		sprite.modulate = Color(0.5, 0.8, 1.0, 1.0)

	# Auto-unfreeze after duration
	await get_tree().create_timer(FREEZE_DURATION).timeout
	_unfreeze()

func _unfreeze():
	if not is_frozen:
		return

	is_frozen = false
	unfrozen.emit()

	# Remove chill effect entirely on unfreeze
	remove_effect(EffectType.CHILL)

	# Restore visuals
	if target and is_instance_valid(target):
		if target.has_node("VisualsPivot"):
			var visuals = target.get_node("VisualsPivot")
			visuals.modulate = Color.WHITE
		elif target.has_node("Sprite2D"):
			var sprite = target.get_node("Sprite2D")
			sprite.modulate = Color.WHITE

# ============================================
# SHOCK CHAIN
# ============================================
# Cache for shock chain targets (refreshed each call since positions change)
var _cached_shock_targets: Array = []
var _cached_shock_group: String = ""

func _trigger_shock_chain(_effect: StatusEffect):
	if not target or not is_instance_valid(target):
		return

	# Find nearby enemies (or player if this is on enemy)
	var group = "player" if target.is_in_group("enemies") else "enemies"
	var potential_targets = get_tree().get_nodes_in_group(group)

	var closest: Node2D = null
	var closest_dist: float = SHOCK_CHAIN_RANGE

	for potential in potential_targets:
		if not is_instance_valid(potential):
			continue
		var dist = target.global_position.distance_to(potential.global_position)
		if dist < closest_dist:
			closest = potential
			closest_dist = dist

	if closest:
		# Deal chain damage - pass null as attacker (shock doesn't trigger thorns)
		if closest.has_method("take_damage"):
			if closest.is_in_group("player"):
				closest.take_damage(SHOCK_CHAIN_DAMAGE, target.global_position)
			else:
				# Pass ELECTRIC damage type for cyan damage numbers
				closest.take_damage(SHOCK_CHAIN_DAMAGE, target.global_position, 100.0, 0.1, null, DamageTypes.Type.ELECTRIC)

		# Visual lightning
		_create_lightning_visual(target.global_position, closest.global_position)
		effect_triggered.emit(EffectType.SHOCK, SHOCK_CHAIN_DAMAGE)

func _create_lightning_visual(from: Vector2, to: Vector2):
	var lightning = Line2D.new()
	lightning.width = 3.0
	lightning.default_color = Color(0.6, 0.8, 1.0, 1.0)

	# Create jagged lightning path
	var points: PackedVector2Array = []
	var segments = 6
	var direction = (to - from).normalized()
	var perpendicular = direction.rotated(PI/2)

	points.append(from)
	for i in range(1, segments):
		var t = float(i) / segments
		var base_point = from.lerp(to, t)
		var offset = perpendicular * randf_range(-15, 15)
		points.append(base_point + offset)
	points.append(to)

	lightning.points = points
	get_tree().current_scene.add_child(lightning)

	# Fade out
	var tween = lightning.create_tween()
	tween.tween_property(lightning, "modulate:a", 0.0, 0.2)
	tween.tween_callback(lightning.queue_free)

# ============================================
# VISUALS
# ============================================
func _create_effect_visual(effect_type: EffectType):
	match effect_type:
		EffectType.BURN:
			if burn_visual:
				return
			burn_visual = _create_particle_aura(Color(1, 0.5, 0.1, 0.6), 4)
		EffectType.CHILL:
			if chill_visual:
				return
			chill_visual = _create_particle_aura(Color(0.5, 0.8, 1.0, 0.5), 3)
		EffectType.SHOCK:
			if shock_visual:
				return
			shock_visual = _create_particle_aura(Color(1, 1, 0.3, 0.4), 2)
		EffectType.BLEED:
			if bleed_visual:
				return
			bleed_visual = _create_particle_aura(Color(0.8, 0.1, 0.1, 0.5), 3)

func _create_particle_aura(color: Color, count: int) -> Node2D:
	var container = Node2D.new()
	target.add_child(container)

	for i in range(count):
		var particle = ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.color = color
		particle.position = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		container.add_child(particle)

		# Animate floating
		var tween = particle.create_tween().set_loops()
		var start_y = particle.position.y
		tween.tween_property(particle, "position:y", start_y - 10, 0.5 + randf() * 0.3)
		tween.tween_property(particle, "position:y", start_y, 0.5 + randf() * 0.3)

	return container

func _remove_effect_visual(effect_type: EffectType):
	match effect_type:
		EffectType.BURN:
			if burn_visual:
				burn_visual.queue_free()
				burn_visual = null
		EffectType.CHILL:
			if chill_visual:
				chill_visual.queue_free()
				chill_visual = null
		EffectType.SHOCK:
			if shock_visual:
				shock_visual.queue_free()
				shock_visual = null
		EffectType.BLEED:
			if bleed_visual:
				bleed_visual.queue_free()
				bleed_visual = null

func _update_visuals():
	# Update visual intensity based on stack count
	for effect_type in active_effects.keys():
		var effect = active_effects[effect_type]
		var visual = _get_visual_for_effect(effect_type)
		if visual and is_instance_valid(visual):
			# Pulse intensity based on stacks
			var intensity = 0.5 + (effect.stacks / float(_get_max_stacks(effect_type))) * 0.5
			visual.modulate.a = intensity

func _get_visual_for_effect(effect_type: EffectType) -> Node2D:
	match effect_type:
		EffectType.BURN: return burn_visual
		EffectType.CHILL: return chill_visual
		EffectType.SHOCK: return shock_visual
		EffectType.BLEED: return bleed_visual
	return null
