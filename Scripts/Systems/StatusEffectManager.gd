# SCRIPT: StatusEffectManager.gd
# AUTOLOAD: StatusEffectManager
# LOCATION: res://Scripts/Systems/StatusEffectManager.gd
# PURPOSE: Enhanced centralized status effect management with complex interactions

extends Node

# ============================================
# EFFECT TYPES - Extended from StatusEffects.gd
# ============================================

enum EffectType {
	# Damage Over Time
	BURN,      # Fire DoT, stacks intensity
	BLEED,     # Physical DoT, increases with movement
	POISON,    # Nature DoT, reduces healing

	# Crowd Control
	CHILL,     # Slow, stacks to freeze
	FREEZE,    # Complete immobilization
	STUN,      # Brief immobilization
	ROOT,      # Can't move but can attack

	# Damage Modifiers
	SHOCK,     # Chain lightning on hit
	VULNERABLE,# Take increased damage
	WEAKEN,    # Deal reduced damage

	# Buffs
	HASTE,     # Increased movement speed
	STRENGTH,  # Increased damage
	SHIELD,    # Damage absorption
	REGEN,     # Heal over time
	LIFESTEAL, # Heal on damage dealt

	# Special
	MARKED,    # Take extra damage from marker
	THORNS,    # Reflect damage
	INVULNERABLE # Cannot take damage
}

enum EffectCategory {
	DEBUFF,
	BUFF,
	CROWD_CONTROL,
	DOT,
	SPECIAL
}

# ============================================
# EFFECT DATA CLASS
# ============================================

class Effect:
	var type: EffectType
	var category: EffectCategory
	var stacks: int = 1
	var max_stacks: int = 1
	var duration: float = 0.0
	var max_duration: float = 0.0
	var tick_timer: float = 0.0
	var tick_rate: float = 0.5
	var source: Node2D = null
	var value: float = 0.0  # Effect-specific value (damage, slow %, etc)
	var can_refresh: bool = true
	var is_permanent: bool = false
	var icon_path: String = ""
	var color: Color = Color.WHITE

	func _init(t: EffectType, dur: float = 0.0, val: float = 0.0, src: Node2D = null):
		type = t
		duration = dur
		max_duration = dur
		value = val
		source = src
		_set_defaults()

	func _set_defaults():
		match type:
			EffectType.BURN:
				category = EffectCategory.DOT
				max_stacks = 5
				tick_rate = 0.5
				color = Color(1, 0.5, 0.1)
			EffectType.BLEED:
				category = EffectCategory.DOT
				max_stacks = 3
				tick_rate = 0.4
				color = Color(0.8, 0.1, 0.1)
			EffectType.POISON:
				category = EffectCategory.DOT
				max_stacks = 3
				tick_rate = 1.0
				color = Color(0.3, 0.8, 0.2)
			EffectType.CHILL:
				category = EffectCategory.CROWD_CONTROL
				max_stacks = 4
				color = Color(0.5, 0.8, 1.0)
			EffectType.FREEZE:
				category = EffectCategory.CROWD_CONTROL
				max_stacks = 1
				color = Color(0.3, 0.6, 1.0)
			EffectType.STUN:
				category = EffectCategory.CROWD_CONTROL
				max_stacks = 1
				color = Color(1, 1, 0.3)
			EffectType.SHOCK:
				category = EffectCategory.DEBUFF
				max_stacks = 1
				color = Color(0.8, 0.9, 1.0)
			EffectType.VULNERABLE:
				category = EffectCategory.DEBUFF
				max_stacks = 3
				color = Color(1, 0.3, 0.8)
			EffectType.WEAKEN:
				category = EffectCategory.DEBUFF
				max_stacks = 3
				color = Color(0.5, 0.3, 0.5)
			EffectType.HASTE:
				category = EffectCategory.BUFF
				max_stacks = 3
				color = Color(0.3, 1, 0.5)
			EffectType.STRENGTH:
				category = EffectCategory.BUFF
				max_stacks = 5
				color = Color(1, 0.3, 0.3)
			EffectType.SHIELD:
				category = EffectCategory.BUFF
				max_stacks = 1
				color = Color(0.8, 0.8, 0.2)
			EffectType.REGEN:
				category = EffectCategory.BUFF
				max_stacks = 3
				tick_rate = 1.0
				color = Color(0.3, 1, 0.3)
			EffectType.LIFESTEAL:
				category = EffectCategory.BUFF
				max_stacks = 1
				color = Color(0.8, 0.2, 0.2)
			EffectType.MARKED:
				category = EffectCategory.SPECIAL
				max_stacks = 1
				color = Color(1, 0.5, 0)
			EffectType.THORNS:
				category = EffectCategory.SPECIAL
				max_stacks = 1
				color = Color(0.6, 0.4, 0.2)
			EffectType.INVULNERABLE:
				category = EffectCategory.SPECIAL
				max_stacks = 1
				color = Color(1, 1, 1)

	func get_progress() -> float:
		if max_duration <= 0:
			return 1.0
		return duration / max_duration

# ============================================
# EFFECT INTERACTIONS - What happens when effects combine
# ============================================

const INTERACTIONS: Dictionary = {
	# FREEZE + BURN = Shatter (instant damage burst)
	"freeze_burn": {"action": "shatter", "damage_mult": 2.0},
	# CHILL + BURN = Cancel both
	"chill_burn": {"action": "cancel_both"},
	# POISON + REGEN = Reduce regen effectiveness
	"poison_regen": {"action": "reduce_effect", "reduction": 0.5},
	# SHOCK + CHILL = Superconductor (increased shock damage)
	"shock_chill": {"action": "enhance", "bonus": 1.5},
	# VULNERABLE + any damage = Bonus damage
	"vulnerable_damage": {"action": "amplify", "mult": 1.25}
}

# ============================================
# STATE - Tracks effects on all entities
# ============================================

# Dictionary of entity_id -> { effect_type -> Effect }
var _entity_effects: Dictionary = {}

# Cached speed modifiers per entity
var _speed_modifiers: Dictionary = {}  # entity_id -> float (multiplier)

# Cached damage modifiers per entity
var _damage_taken_modifiers: Dictionary = {}  # entity_id -> float
var _damage_dealt_modifiers: Dictionary = {}  # entity_id -> float

# ============================================
# SIGNALS
# ============================================

signal effect_applied(entity: Node2D, effect: Effect)
signal effect_stacked(entity: Node2D, effect: Effect, new_stacks: int)
signal effect_refreshed(entity: Node2D, effect: Effect)
signal effect_removed(entity: Node2D, effect_type: EffectType)
signal effect_triggered(entity: Node2D, effect_type: EffectType, value: float)
signal effect_interaction(entity: Node2D, effect1: EffectType, effect2: EffectType, result: String)
signal shield_absorbed(entity: Node2D, damage: float, remaining: float)

# ============================================
# PUBLIC API
# ============================================

## Apply an effect to an entity
func apply_effect(entity: Node2D, effect_type: EffectType, duration: float = 0.0,
				  value: float = 0.0, source: Node2D = null, stacks: int = 1) -> Effect:
	if not is_instance_valid(entity):
		return null

	var entity_id = entity.get_instance_id()

	# Initialize entity tracking if needed
	if entity_id not in _entity_effects:
		_entity_effects[entity_id] = {}
		# Connect to entity's tree_exiting to clean up
		entity.tree_exiting.connect(_on_entity_removed.bind(entity_id))

	var effects = _entity_effects[entity_id]

	# Check for effect interactions before applying
	_check_interactions_before_apply(entity, effect_type)

	# Check if effect already exists
	if effect_type in effects:
		var existing = effects[effect_type]

		# Stack or refresh
		if existing.stacks < existing.max_stacks:
			existing.stacks = min(existing.stacks + stacks, existing.max_stacks)
			effect_stacked.emit(entity, existing, existing.stacks)

		if existing.can_refresh:
			existing.duration = existing.max_duration
			effect_refreshed.emit(entity, existing)

		existing.source = source
		_update_modifiers(entity)
		return existing
	else:
		# Create new effect
		var effect = Effect.new(effect_type, duration, value, source)
		effect.stacks = min(stacks, effect.max_stacks)
		effects[effect_type] = effect

		effect_applied.emit(entity, effect)
		_update_modifiers(entity)

		# Handle immediate effects
		_on_effect_applied(entity, effect)

		return effect

## Remove an effect from an entity
func remove_effect(entity: Node2D, effect_type: EffectType) -> void:
	if not is_instance_valid(entity):
		return

	var entity_id = entity.get_instance_id()
	if entity_id not in _entity_effects:
		return

	var effects = _entity_effects[entity_id]
	if effect_type in effects:
		var effect = effects[effect_type]
		_on_effect_removed(entity, effect)
		effects.erase(effect_type)
		effect_removed.emit(entity, effect_type)
		_update_modifiers(entity)

## Remove all effects from an entity
## Pass category = -1 to clear all effects regardless of category
func clear_effects(entity: Node2D, category: int = -1) -> void:
	if not is_instance_valid(entity):
		return

	var entity_id = entity.get_instance_id()
	if entity_id not in _entity_effects:
		return

	var to_remove: Array = []
	for effect_type in _entity_effects[entity_id]:
		var effect = _entity_effects[entity_id][effect_type]
		if category == -1 or effect.category == category:
			to_remove.append(effect_type)

	for effect_type in to_remove:
		remove_effect(entity, effect_type)

## Check if entity has an effect
func has_effect(entity: Node2D, effect_type: EffectType) -> bool:
	if not is_instance_valid(entity):
		return false
	var entity_id = entity.get_instance_id()
	if entity_id not in _entity_effects:
		return false
	return effect_type in _entity_effects[entity_id]

## Get effect stacks
func get_stacks(entity: Node2D, effect_type: EffectType) -> int:
	if not is_instance_valid(entity):
		return 0
	var entity_id = entity.get_instance_id()
	if entity_id not in _entity_effects:
		return 0
	if effect_type not in _entity_effects[entity_id]:
		return 0
	return _entity_effects[entity_id][effect_type].stacks

## Get all effects on an entity
func get_effects(entity: Node2D) -> Array:
	if not is_instance_valid(entity):
		return []
	var entity_id = entity.get_instance_id()
	if entity_id not in _entity_effects:
		return []
	return _entity_effects[entity_id].values()

## Get speed modifier for entity (1.0 = normal)
func get_speed_modifier(entity: Node2D) -> float:
	var entity_id = entity.get_instance_id()
	return _speed_modifiers.get(entity_id, 1.0)

## Get damage taken modifier (1.0 = normal, higher = more damage)
func get_damage_taken_modifier(entity: Node2D) -> float:
	var entity_id = entity.get_instance_id()
	return _damage_taken_modifiers.get(entity_id, 1.0)

## Get damage dealt modifier (1.0 = normal)
func get_damage_dealt_modifier(entity: Node2D) -> float:
	var entity_id = entity.get_instance_id()
	return _damage_dealt_modifiers.get(entity_id, 1.0)

## Process shield absorption - returns remaining damage after shield
func process_shield(entity: Node2D, damage: float) -> float:
	if not has_effect(entity, EffectType.SHIELD):
		return damage

	var entity_id = entity.get_instance_id()
	var shield = _entity_effects[entity_id][EffectType.SHIELD]

	var absorbed = min(damage, shield.value)
	shield.value -= absorbed

	shield_absorbed.emit(entity, absorbed, shield.value)

	if shield.value <= 0:
		remove_effect(entity, EffectType.SHIELD)

	return damage - absorbed

# ============================================
# PROCESS LOOP
# ============================================

func _process(delta):
	var entities_to_clean: Array = []

	for entity_id in _entity_effects:
		# Check if entity still exists
		var entity = instance_from_id(entity_id) as Node2D
		if not is_instance_valid(entity):
			entities_to_clean.append(entity_id)
			continue

		var effects = _entity_effects[entity_id]
		var expired: Array = []

		for effect_type in effects:
			var effect = effects[effect_type]

			if effect.is_permanent:
				continue

			# Update duration
			effect.duration -= delta
			if effect.duration <= 0:
				expired.append(effect_type)
				continue

			# Process ticks
			effect.tick_timer -= delta
			if effect.tick_timer <= 0:
				effect.tick_timer = effect.tick_rate
				_process_tick(entity, effect)

		# Remove expired effects
		for effect_type in expired:
			remove_effect(entity, effect_type)

	# Clean up dead entities
	for entity_id in entities_to_clean:
		_entity_effects.erase(entity_id)
		_speed_modifiers.erase(entity_id)
		_damage_taken_modifiers.erase(entity_id)
		_damage_dealt_modifiers.erase(entity_id)

# ============================================
# INTERNAL PROCESSING
# ============================================

func _process_tick(entity: Node2D, effect: Effect):
	match effect.type:
		EffectType.BURN:
			var damage = effect.value * effect.stacks
			_deal_effect_damage(entity, damage, effect.type, effect.source)
			effect_triggered.emit(entity, effect.type, damage)

		EffectType.BLEED:
			var damage = effect.value * effect.stacks
			# Could track movement here for bonus damage
			_deal_effect_damage(entity, damage, effect.type, effect.source)
			effect_triggered.emit(entity, effect.type, damage)

		EffectType.POISON:
			var damage = effect.value * effect.stacks
			_deal_effect_damage(entity, damage, effect.type, effect.source)
			effect_triggered.emit(entity, effect.type, damage)

		EffectType.REGEN:
			var heal = effect.value * effect.stacks
			if entity.has_method("heal"):
				entity.heal(heal)
			effect_triggered.emit(entity, effect.type, heal)

		EffectType.SHOCK:
			# Random chance to chain
			if randf() < 0.3:
				_trigger_shock_chain(entity, effect)

func _deal_effect_damage(entity: Node2D, damage: float, effect_type: EffectType, source: Node2D):
	if not entity.has_method("take_damage"):
		return

	# Map effect to damage type
	var damage_type = _get_damage_type(effect_type)

	# Validate source is still valid (may have been freed since effect was applied)
	var valid_source = source if is_instance_valid(source) else null

	if entity.is_in_group("player"):
		entity.take_damage(damage, Vector2.ZERO)
	else:
		entity.take_damage(damage, Vector2.ZERO, 0.0, 0.0, valid_source, damage_type)

func _get_damage_type(effect_type: EffectType) -> int:
	match effect_type:
		EffectType.BURN:
			return DamageTypes.Type.FIRE if DamageTypes else 0
		EffectType.SHOCK:
			return DamageTypes.Type.ELECTRIC if DamageTypes else 0
		EffectType.BLEED:
			return DamageTypes.Type.BLEED if DamageTypes else 0
		EffectType.POISON:
			return DamageTypes.Type.POISON if DamageTypes else 0
	return 0

func _trigger_shock_chain(entity: Node2D, effect: Effect):
	var group = "player" if entity.is_in_group("enemies") else "enemies"
	var targets = get_tree().get_nodes_in_group(group)

	var closest: Node2D = null
	var closest_dist = 150.0  # Chain range

	for target in targets:
		if not is_instance_valid(target) or target == entity:
			continue
		var dist = entity.global_position.distance_to(target.global_position)
		if dist < closest_dist:
			closest = target
			closest_dist = dist

	if closest:
		var chain_damage = effect.value * 0.5
		var valid_source = effect.source if is_instance_valid(effect.source) else null
		_deal_effect_damage(closest, chain_damage, EffectType.SHOCK, valid_source)
		effect_triggered.emit(entity, EffectType.SHOCK, chain_damage)

# ============================================
# EFFECT INTERACTIONS
# ============================================

func _check_interactions_before_apply(entity: Node2D, new_effect: EffectType):
	var entity_id = entity.get_instance_id()
	if entity_id not in _entity_effects:
		return

	var effects = _entity_effects[entity_id]

	# FREEZE + BURN = Shatter
	if new_effect == EffectType.BURN and EffectType.FREEZE in effects:
		_trigger_shatter(entity, effects[EffectType.FREEZE])
		remove_effect(entity, EffectType.FREEZE)
		effect_interaction.emit(entity, EffectType.FREEZE, EffectType.BURN, "shatter")

	# CHILL + BURN = Cancel
	elif new_effect == EffectType.BURN and EffectType.CHILL in effects:
		remove_effect(entity, EffectType.CHILL)
		effect_interaction.emit(entity, EffectType.CHILL, EffectType.BURN, "cancel")
		return  # Don't apply burn

	elif new_effect == EffectType.CHILL and EffectType.BURN in effects:
		remove_effect(entity, EffectType.BURN)
		effect_interaction.emit(entity, EffectType.BURN, EffectType.CHILL, "cancel")
		return  # Don't apply chill

func _trigger_shatter(entity: Node2D, freeze_effect: Effect):
	# Big burst of ice damage
	var shatter_damage = freeze_effect.value * 2.0
	var valid_source = freeze_effect.source if is_instance_valid(freeze_effect.source) else null
	_deal_effect_damage(entity, shatter_damage, EffectType.FREEZE, valid_source)

	# Visual effect
	_create_shatter_visual(entity.global_position)

func _create_shatter_visual(pos: Vector2):
	# Create ice shard particles
	for i in range(8):
		var shard = ColorRect.new()
		shard.size = Vector2(6, 12)
		shard.color = Color(0.5, 0.8, 1.0, 0.8)
		shard.pivot_offset = shard.size / 2
		get_tree().current_scene.add_child(shard)
		shard.global_position = pos

		var angle = TAU / 8 * i
		var dir = Vector2.from_angle(angle)
		shard.rotation = angle

		var tween = shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", pos + dir * 60, 0.3)
		tween.tween_property(shard, "modulate:a", 0.0, 0.3)
		tween.tween_property(shard, "rotation", angle + PI, 0.3)
		tween.chain().tween_callback(shard.queue_free)

# ============================================
# MODIFIER UPDATES
# ============================================

func _update_modifiers(entity: Node2D):
	var entity_id = entity.get_instance_id()
	if entity_id not in _entity_effects:
		return

	var effects = _entity_effects[entity_id]
	var speed_mod = 1.0
	var damage_taken_mod = 1.0
	var damage_dealt_mod = 1.0

	for effect_type in effects:
		var effect = effects[effect_type]
		match effect_type:
			EffectType.CHILL:
				speed_mod *= (1.0 - 0.15 * effect.stacks)  # 15% slow per stack
			EffectType.FREEZE:
				speed_mod = 0.0
			EffectType.HASTE:
				speed_mod *= (1.0 + 0.20 * effect.stacks)  # 20% speed per stack
			EffectType.ROOT:
				speed_mod = 0.0
			EffectType.VULNERABLE:
				damage_taken_mod *= (1.0 + 0.15 * effect.stacks)  # 15% more damage per stack
			EffectType.WEAKEN:
				damage_dealt_mod *= (1.0 - 0.15 * effect.stacks)  # 15% less damage per stack
			EffectType.STRENGTH:
				damage_dealt_mod *= (1.0 + 0.10 * effect.stacks)  # 10% more damage per stack

	_speed_modifiers[entity_id] = speed_mod
	_damage_taken_modifiers[entity_id] = damage_taken_mod
	_damage_dealt_modifiers[entity_id] = damage_dealt_mod

func _on_effect_applied(entity: Node2D, effect: Effect):
	# Emit to CombatEventBus if available
	if CombatEventBus:
		CombatEventBus.emit_status_applied(entity, effect.type, effect.stacks)

func _on_effect_removed(entity: Node2D, effect: Effect):
	if CombatEventBus:
		CombatEventBus.emit_status_removed(entity, effect.type)

func _on_entity_removed(entity_id: int):
	_entity_effects.erase(entity_id)
	_speed_modifiers.erase(entity_id)
	_damage_taken_modifiers.erase(entity_id)
	_damage_dealt_modifiers.erase(entity_id)

# ============================================
# CONVENIENCE FUNCTIONS
# ============================================

## Apply burn (fire DoT)
func apply_burn(entity: Node2D, damage_per_tick: float, duration: float = 3.0, source: Node2D = null) -> Effect:
	return apply_effect(entity, EffectType.BURN, duration, damage_per_tick, source)

## Apply chill (slow, stacks to freeze)
func apply_chill(entity: Node2D, duration: float = 2.5, source: Node2D = null, stacks: int = 1) -> Effect:
	var effect = apply_effect(entity, EffectType.CHILL, duration, 0.15, source, stacks)
	# Auto-freeze at max stacks
	if effect and effect.stacks >= effect.max_stacks:
		apply_freeze(entity, 1.5, source)
		remove_effect(entity, EffectType.CHILL)
	return effect

## Apply freeze (complete immobilization)
func apply_freeze(entity: Node2D, duration: float = 1.5, source: Node2D = null) -> Effect:
	return apply_effect(entity, EffectType.FREEZE, duration, 0.0, source)

## Apply stun
func apply_stun(entity: Node2D, duration: float = 0.5, source: Node2D = null) -> Effect:
	return apply_effect(entity, EffectType.STUN, duration, 0.0, source)

## Apply vulnerability
func apply_vulnerable(entity: Node2D, duration: float = 5.0, source: Node2D = null, stacks: int = 1) -> Effect:
	return apply_effect(entity, EffectType.VULNERABLE, duration, 0.15, source, stacks)

## Apply shield
func apply_shield(entity: Node2D, amount: float, duration: float = 10.0) -> Effect:
	return apply_effect(entity, EffectType.SHIELD, duration, amount, null)

## Apply regen
func apply_regen(entity: Node2D, heal_per_tick: float, duration: float = 5.0) -> Effect:
	return apply_effect(entity, EffectType.REGEN, duration, heal_per_tick, null)

## Check if entity is crowd controlled
func is_cc(entity: Node2D) -> bool:
	return has_effect(entity, EffectType.FREEZE) or \
		   has_effect(entity, EffectType.STUN) or \
		   has_effect(entity, EffectType.ROOT)

## Check if entity can move
func can_move(entity: Node2D) -> bool:
	return not (has_effect(entity, EffectType.FREEZE) or \
				has_effect(entity, EffectType.STUN) or \
				has_effect(entity, EffectType.ROOT))
