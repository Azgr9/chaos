# SCRIPT: Enemy.gd
# ATTACH TO: Nothing - this is a base class
# LOCATION: res://Scripts/Enemies/Enemy.gd

class_name Enemy
extends CharacterBody2D

# ============================================
# PRELOADED SCENES
# ============================================
const ChaosCrystal = preload("res://Scenes/Items/ChaosCrystal.tscn")

# ============================================
# CONSTANTS
# ============================================
const MIN_OVERLAP_DISTANCE: float = 100.0
const OVERLAP_PUSH_STRENGTH: float = 400.0
const DEFAULT_KNOCKBACK_POWER: float = 600.0
const KNOCKBACK_DECAY_RATE: float = 10.0
const KNOCKBACK_MIN_THRESHOLD: float = 5.0

# Hit flash settings (consistent across all enemies) - SNAPPY timing
const HIT_FLASH_COLOR: Color = Color(10.0, 10.0, 10.0, 1.0)  # Very bright white
const HIT_FLASH_DURATION: float = 0.04  # Quick flash (was 0.12)
const HIT_SQUASH_SCALE: Vector2 = Vector2(1.2, 0.8)  # Squash on hit
const HIT_SQUASH_DURATION: float = 0.08  # Quick squash recovery (was 0.25)

# Death animation settings - Enhanced effects
const DEATH_FADE_DURATION: float = 0.2  # Death fade
const DEATH_PARTICLE_DURATION: float = 0.35  # Particle fade
const DEATH_PARTICLE_DISTANCE: float = 80.0  # Particle travel
const HEALTH_BAR_FADE_DURATION: float = 0.1  # Quick health bar fade

# Enhanced death particle settings
const DEATH_SPARK_COUNT: int = 8  # Number of spark particles
const DEATH_SMOKE_COUNT: int = 4  # Number of smoke puffs
const DEATH_RING_ENABLED: bool = true  # Whether to show death ring

# ============================================
# EXPORTED STATS
# ============================================
@export_group("Info")
@export var enemy_type: String = "unknown"  # For bestiary tracking
@export var enemy_display_name: String = "Unknown Enemy"  # Display name in bestiary

@export_group("Stats")
@export var max_health: float = 30.0
@export var move_speed: float = 240.0
@export var damage: float = 10.0
@export var knockback_resistance: float = 0.5

@export_group("Drops")
@export var experience_value: int = 10
@export var crystal_drop_chance: float = 0.7
@export var min_crystals: int = 1
@export var max_crystals: int = 3
# Gold drops - base values, scaled by WaveManager based on wave/arena
# Economy target: ~450-600 gold for full 10-wave clear (wave 3 death ~80 gold)
# Shop weapons cost 25-90 gold, so players can afford ~1-2 weapons mid-run
@export var gold_drop_min: int = 3
@export var gold_drop_max: int = 6

@export_group("Visual")
@export var health_bar_width: float = 80.0

# ============================================
# STATE
# ============================================
var current_health: float
var player_reference: Node2D = null
var is_dead: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var hitstun_timer: float = 0.0
var is_stunned: bool = false
var last_attacker: Node2D = null  # Track who killed this enemy

# Health bar nodes (auto-detected or set by subclass)
var health_bar: Node2D = null
var health_fill: ColorRect = null

# Elite system
var elite_modifier: EliteModifier = null
var is_elite: bool = false

# Status effects
var status_effects: StatusEffects = null

# Hit flash state
var _flash_tween: Tween = null

# Health bar optimization - track last shown health to avoid recalculating every frame
var _last_health_shown: float = -1.0

# ============================================
# SIGNALS
# ============================================
signal enemy_died(enemy: Enemy)
@warning_ignore("unused_signal")  # Emitted by subclasses (e.g., Slime)
signal damage_dealt(amount: float)
signal health_changed(current: float, max_val: float)

# ============================================
# LIFECYCLE
# ============================================
func _ready():
	current_health = max_health
	add_to_group("enemies")

	# Cache player reference
	if not player_reference:
		player_reference = get_tree().get_first_node_in_group("player")

	# Auto-detect health bar nodes
	_setup_health_bar()

	# Call subclass setup
	_setup_enemy()

func _physics_process(delta):
	if is_dead:
		return

	_update_hitstun(delta)

	if not is_stunned:
		_update_movement(delta)

	_apply_knockback(delta)
	_avoid_player_overlap()
	move_and_slide()

	# Update health bar
	_update_health_bar()

# ============================================
# VIRTUAL METHODS - Override in subclasses
# ============================================
func _setup_enemy():
	# Override in child classes for specific setup
	pass

func _update_movement(_delta):
	# Override in child classes for specific movement patterns
	pass

# ============================================
# TARGET SELECTION - Includes player minions
# ============================================
## Returns the best target (player or nearest minion)
func get_best_target() -> Node2D:
	var best_target: Node2D = null
	var best_distance: float = INF

	# If this is a converted minion, target real enemies instead
	if is_in_group("converted_minion"):
		return _get_best_enemy_target()

	# Check player
	if player_reference and is_instance_valid(player_reference):
		best_target = player_reference
		best_distance = global_position.distance_to(player_reference.global_position)

	# Check player minions (NecroStaff converted enemies)
	var minions = get_tree().get_nodes_in_group("player_minions")
	for minion in minions:
		if not is_instance_valid(minion):
			continue
		var dist = global_position.distance_to(minion.global_position)
		if dist < best_distance:
			best_distance = dist
			best_target = minion

	return best_target

## For converted minions - find nearest real enemy to attack
func _get_best_enemy_target() -> Node2D:
	var best_target: Node2D = null
	var best_distance: float = 500.0  # Max targeting range

	# Find real enemies (not other converted minions or portals)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		# Skip other converted minions
		if enemy.is_in_group("converted_minion"):
			continue
		# Skip portals - don't attack them!
		if enemy.is_in_group("portal"):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < best_distance:
			best_distance = dist
			best_target = enemy

	# If no enemies nearby, follow player
	if not best_target:
		var player = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			var dist_to_player = global_position.distance_to(player.global_position)
			# Only follow if far from player
			if dist_to_player > 150:
				best_target = player

	return best_target

## Returns direction to best target
func get_direction_to_target() -> Vector2:
	var target = get_best_target()
	if target:
		return (target.global_position - global_position).normalized()
	return Vector2.ZERO

func _on_damage_taken():
	# Base hit flash effect - called automatically, subclasses can override for additional effects
	_play_hit_flash()

func _play_hit_flash():
	# Kill any existing flash tween to prevent overlap
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	# Instant bright white flash
	modulate = HIT_FLASH_COLOR

	# Determine target color - converted minions return to purple, others to white
	var target_color = Color.WHITE
	if is_in_group("converted_minion"):
		target_color = Color(0.4, 0.2, 0.6, 1.0)  # Dark purple for minions

	# Restore to appropriate color - prevents color corruption from rapid damage
	_flash_tween = TweenHelper.new_tween()
	_flash_tween.tween_property(self, "modulate", target_color, HIT_FLASH_DURATION)

	# Squash effect on visuals pivot if it exists
	_play_hit_squash()

func _play_hit_squash():
	# Override in subclasses that have visuals_pivot
	pass

func _get_visuals_pivot() -> Node2D:
	# Override in subclasses to return their visuals pivot node
	return null

func _on_death():
	# Override for specific death effects
	# Default: just queue_free
	queue_free()

func _get_death_particle_color() -> Color:
	# Override to customize death particle color
	return Color.WHITE

func _get_death_particle_count() -> int:
	# Override to customize particle count
	return 5

# ============================================
# HEALTH BAR SYSTEM (Consolidated)
# ============================================
func _setup_health_bar():
	# Auto-detect health bar nodes in scene tree
	if has_node("HealthBar"):
		health_bar = get_node("HealthBar")
		if health_bar.has_node("Fill"):
			health_fill = health_bar.get_node("Fill")
		health_bar.visible = false

func _update_health_bar():
	if not health_bar or not health_fill:
		return

	# Only update if health bar is visible AND health has changed
	if health_bar.visible and current_health != _last_health_shown:
		_last_health_shown = current_health
		var health_percentage = current_health / max_health
		health_fill.size.x = health_bar_width * health_percentage

func show_health_bar():
	if health_bar:
		health_bar.visible = true

# ============================================
# COMBAT SYSTEM
# ============================================
func _update_hitstun(delta):
	if hitstun_timer > 0:
		hitstun_timer -= delta
		is_stunned = true
		if hitstun_timer <= 0:
			hitstun_timer = 0
			is_stunned = false
	else:
		is_stunned = false

func _avoid_player_overlap():
	if not player_reference:
		return

	var to_player = player_reference.global_position - global_position
	var distance = to_player.length()

	if distance < MIN_OVERLAP_DISTANCE and distance > 0:
		var push_direction = -to_player.normalized()
		var push_strength = (MIN_OVERLAP_DISTANCE - distance) / MIN_OVERLAP_DISTANCE

		if knockback_velocity.length() == 0:
			velocity += push_direction * push_strength * OVERLAP_PUSH_STRENGTH

func take_damage(amount: float, from_position: Vector2 = Vector2.ZERO, knockback_power: float = DEFAULT_KNOCKBACK_POWER, stun_duration: float = 0.0, attacker: Node2D = null, damage_type: DamageTypes.Type = DamageTypes.Type.PHYSICAL):
	if is_dead:
		return

	# Apply elite modifier damage reduction (thorns, shield, etc.)
	var final_damage = amount
	if elite_modifier and is_elite:
		final_damage = elite_modifier.on_take_damage(amount, attacker)

	# Apply relic damage multipliers (berserker, void vulnerability, etc.)
	if RelicEffectManager:
		final_damage *= RelicEffectManager.get_damage_multiplier()
		final_damage *= RelicEffectManager.apply_void_vulnerability(self)

	current_health -= final_damage
	health_changed.emit(current_health, max_health)

	# Apply relic on-hit effects (burn, chill, etc.)
	if RelicEffectManager and attacker and attacker.is_in_group("player"):
		RelicEffectManager.on_enemy_hit(self, from_position)

	# Check for death first - don't apply hitstun to dead enemies
	if current_health <= 0:
		# Store who killed us
		last_attacker = attacker
		# Show health bar and damage number before death
		show_health_bar()
		_spawn_damage_number(final_damage, damage_type)
		die()
		return

	# Show health bar when damaged
	show_health_bar()

	# Spawn damage number
	_spawn_damage_number(final_damage, damage_type)

	# Apply knockback (only if alive)
	if from_position != Vector2.ZERO:
		var knockback_direction = (global_position - from_position).normalized()
		knockback_velocity = knockback_direction * (knockback_power * (1.0 - knockback_resistance))

	# Apply hitstun (only if alive)
	if stun_duration > 0:
		hitstun_timer = stun_duration

	# Apply status effect based on damage type
	_apply_status_from_damage_type(damage_type, attacker)

	# Visual feedback (subclass override)
	_on_damage_taken()

func _spawn_damage_number(damage_amount: float, damage_type: DamageTypes.Type = DamageTypes.Type.PHYSICAL):
	DamageNumberManager.spawn(global_position, damage_amount, damage_type)

func _apply_status_from_damage_type(damage_type: DamageTypes.Type, attacker: Node2D = null):
	# Automatically apply status effects based on damage type
	match damage_type:
		DamageTypes.Type.FIRE:
			apply_status_effect(StatusEffects.EffectType.BURN, attacker)
		DamageTypes.Type.ICE:
			apply_status_effect(StatusEffects.EffectType.CHILL, attacker)
		DamageTypes.Type.ELECTRIC:
			apply_status_effect(StatusEffects.EffectType.SHOCK, attacker)
		DamageTypes.Type.BLEED:
			apply_status_effect(StatusEffects.EffectType.BLEED, attacker)

# ============================================
# DEATH SYSTEM (Consolidated)
# ============================================
func die():
	is_dead = true
	enemy_died.emit(self)

	# Notify CombatEventBus (for NecroStaff minion spawning, etc.)
	if CombatEventBus:
		CombatEventBus.emit_kill(last_attacker, self)

	# Track kill in bestiary
	if RunManager:
		RunManager.add_kill_by_type(enemy_type)

	# Screen shake
	_add_screen_shake(0.3)

	# Spawn drops
	_spawn_crystals()
	_drop_gold()

	# Notify player for lifesteal
	if player_reference and player_reference.has_method("on_enemy_killed"):
		player_reference.on_enemy_killed()

	# Create death particles (common effect)
	_create_death_particles()

	# Fade out health bar quickly
	if health_bar:
		var tween = TweenHelper.new_tween()
		tween.tween_property(health_bar, "modulate:a", 0.0, HEALTH_BAR_FADE_DURATION)

	# Call subclass death handler
	_on_death()

func _create_death_particles():
	var particle_count = _get_death_particle_count()
	var particle_color = _get_death_particle_color()
	var scene = get_tree().current_scene
	if not scene:
		return

	# Main death burst ring
	if DEATH_RING_ENABLED:
		_create_death_ring(scene, particle_color)

	# Core particles (chunks)
	for i in range(particle_count):
		var particle = ColorRect.new()
		var size = randf_range(8, 16)
		particle.size = Vector2(size, size)
		particle.pivot_offset = particle.size / 2
		particle.color = particle_color
		scene.add_child(particle)
		particle.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))

		var particle_tween = TweenHelper.new_tween()
		var angle = randf() * TAU
		var distance = randf_range(DEATH_PARTICLE_DISTANCE * 0.5, DEATH_PARTICLE_DISTANCE)
		var end_pos = particle.global_position + Vector2.from_angle(angle) * distance

		particle_tween.set_parallel(true)
		particle_tween.tween_property(particle, "global_position", end_pos, DEATH_PARTICLE_DURATION)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		particle_tween.tween_property(particle, "global_position:y", end_pos.y + 30, DEATH_PARTICLE_DURATION)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		particle_tween.tween_property(particle, "rotation", randf_range(-PI, PI), DEATH_PARTICLE_DURATION)
		particle_tween.tween_property(particle, "scale", Vector2(0.2, 0.2), DEATH_PARTICLE_DURATION)
		particle_tween.tween_property(particle, "modulate:a", 0.0, DEATH_PARTICLE_DURATION)
		particle_tween.tween_callback(particle.queue_free)

	# Spark particles (bright white/yellow)
	_create_death_sparks(scene, particle_color)

	# Smoke puffs
	_create_death_smoke(scene)

func _create_death_ring(scene: Node, base_color: Color):
	# Expanding ring on death
	var ring = ColorRect.new()
	ring.size = Vector2(30, 30)
	ring.pivot_offset = Vector2(15, 15)
	ring.color = Color(base_color.r, base_color.g, base_color.b, 0.6)
	scene.add_child(ring)
	ring.global_position = global_position - Vector2(15, 15)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(5, 5), 0.25)
	tween.tween_property(ring, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ring.queue_free)

	# Inner bright flash
	var flash = ColorRect.new()
	flash.size = Vector2(50, 50)
	flash.pivot_offset = Vector2(25, 25)
	flash.color = Color(1.0, 1.0, 1.0, 0.8)
	scene.add_child(flash)
	flash.global_position = global_position - Vector2(25, 25)

	var flash_tween = TweenHelper.new_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(2, 2), 0.1)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	flash_tween.tween_callback(flash.queue_free)

func _create_death_sparks(scene: Node, base_color: Color):
	# Bright spark particles
	for i in range(DEATH_SPARK_COUNT):
		var spark = ColorRect.new()
		spark.size = Vector2(4, 12)  # Elongated sparks
		spark.pivot_offset = Vector2(2, 6)
		# Mix base color with white for brighter sparks
		spark.color = base_color.lerp(Color.WHITE, 0.6)
		scene.add_child(spark)
		spark.global_position = global_position

		var angle = randf() * TAU
		var speed = randf_range(150, 250)
		var end_pos = global_position + Vector2.from_angle(angle) * speed * 0.3

		spark.rotation = angle + PI / 2  # Point in direction of travel

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", end_pos, 0.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "scale", Vector2(0.1, 0.1), 0.2)
		tween.tween_property(spark, "modulate:a", 0.0, 0.2)
		tween.tween_callback(spark.queue_free)

func _create_death_smoke(scene: Node):
	# Smoke puff particles
	for i in range(DEATH_SMOKE_COUNT):
		var smoke = ColorRect.new()
		var size = randf_range(20, 35)
		smoke.size = Vector2(size, size)
		smoke.pivot_offset = smoke.size / 2
		smoke.color = Color(0.3, 0.3, 0.3, 0.5)  # Gray smoke
		scene.add_child(smoke)
		smoke.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-10, 10))

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		# Smoke rises and expands
		tween.tween_property(smoke, "global_position:y", smoke.global_position.y - randf_range(40, 70), 0.5)
		tween.tween_property(smoke, "scale", Vector2(2, 2), 0.5)
		tween.tween_property(smoke, "modulate:a", 0.0, 0.5)
		tween.tween_callback(smoke.queue_free)

func _drop_gold():
	if RunManager:
		var base_gold = randi_range(gold_drop_min, gold_drop_max)
		# Apply fortune training bonus from SaveManager
		var fortune_mult = 1.0
		if SaveManager:
			fortune_mult = SaveManager.get_fortune_gold_multiplier()
		var gold_amount = int(base_gold * fortune_mult)
		RunManager.add_gold(gold_amount)

func _spawn_crystals():
	if randf() > crystal_drop_chance:
		return

	var num_crystals = randi_range(min_crystals, max_crystals)

	for i in range(num_crystals):
		var crystal = ChaosCrystal.instantiate()
		var offset = Vector2(randf_range(-60, 60), randf_range(-60, 60))
		crystal.global_position = global_position + offset
		var scene = get_tree().current_scene
		if scene:
			scene.call_deferred("add_child", crystal)
		else:
			crystal.queue_free()

func _add_screen_shake(trauma_amount: float):
	DamageNumberManager.shake(trauma_amount)

# ============================================
# UTILITY
# ============================================
func set_player_reference(player: Node2D):
	player_reference = player

# ============================================
# ELITE SYSTEM
# ============================================
func make_elite(modifier_type: EliteModifier.ModifierType = EliteModifier.ModifierType.THORNS):
	if is_elite:
		return

	is_elite = true

	# Create and setup elite modifier
	elite_modifier = EliteModifier.new()
	add_child(elite_modifier)
	elite_modifier.setup_elite(modifier_type)

func make_random_elite():
	make_elite(EliteModifier.get_random_modifier())

# ============================================
# STATUS EFFECTS
# ============================================
# Note: Uses component-based StatusEffects for per-entity tracking
# StatusEffectManager autoload can also apply effects via apply_effect()

func apply_status_effect(effect_type: StatusEffects.EffectType, source: Node2D = null, stacks: int = 1):
	# Use component-based system for visual effects attached to this entity
	if not status_effects:
		status_effects = StatusEffects.new()
		add_child(status_effects)

	status_effects.apply_effect(effect_type, source, stacks)

	# Also notify centralized manager if available (for cross-system effects)
	if StatusEffectManager:
		# Map local effect type to manager effect type
		var manager_type = _map_to_manager_effect_type(effect_type)
		if manager_type >= 0:
			StatusEffectManager.apply_effect(self, manager_type, status_effects._get_duration(effect_type), 0.0, source, stacks)

func _map_to_manager_effect_type(local_type: StatusEffects.EffectType) -> int:
	# Map StatusEffects.EffectType to StatusEffectManager.EffectType
	if not StatusEffectManager:
		return -1
	match local_type:
		StatusEffects.EffectType.BURN: return StatusEffectManager.EffectType.BURN
		StatusEffects.EffectType.CHILL: return StatusEffectManager.EffectType.CHILL
		StatusEffects.EffectType.SHOCK: return StatusEffectManager.EffectType.SHOCK
		StatusEffects.EffectType.BLEED: return StatusEffectManager.EffectType.BLEED
	return -1

func has_status_effect(effect_type: StatusEffects.EffectType) -> bool:
	if status_effects:
		return status_effects.has_effect(effect_type)
	return false

# ============================================
# HAZARD INTERACTION
# ============================================
func _apply_knockback(delta):
	if knockback_velocity.length() > 0:
		velocity = knockback_velocity

		# Check for hazard collision during knockback
		_check_hazard_collision()

		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, KNOCKBACK_DECAY_RATE * delta)
		if knockback_velocity.length() < KNOCKBACK_MIN_THRESHOLD:
			knockback_velocity = Vector2.ZERO

func _check_hazard_collision():
	# Check if enemy is knocked into a hazard
	var hazards = get_tree().get_nodes_in_group("hazards")
	for hazard in hazards:
		if not is_instance_valid(hazard):
			continue

		# Check distance to hazard center
		var dist = global_position.distance_to(hazard.global_position)
		var hazard_radius = 48.0  # Approximate hazard size

		if dist < hazard_radius:
			_on_knocked_into_hazard(hazard)
			break

func _on_knocked_into_hazard(hazard: Node2D):
	# Bonus damage when knocked into hazards
	var bonus_damage = 15.0

	# Regular hazard - take bonus damage
	if hazard.has_method("apply_damage"):
		# Let hazard handle damage
		pass
	else:
		# Manual bonus damage
		take_damage(bonus_damage, hazard.global_position, 0.0, 0.2, null)
		_create_hazard_hit_effect()

func _create_hazard_hit_effect():
	# Effect when knocked into damaging hazard
	var flash = ColorRect.new()
	flash.size = Vector2(40, 40)
	flash.position = Vector2(-20, -20)
	flash.color = Color(1, 0.5, 0.2, 0.6)
	add_child(flash)

	var tween = TweenHelper.new_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)
