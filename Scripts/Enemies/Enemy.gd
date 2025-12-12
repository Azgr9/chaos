# SCRIPT: Enemy.gd
# ATTACH TO: Nothing - this is a base class
# LOCATION: res://Scripts/Enemies/Enemy.gd

class_name Enemy
extends CharacterBody2D

# ============================================
# PRELOADED SCENES
# ============================================
const DamageNumber = preload("res://Scenes/Ui/DamageNumber.tscn")
const ChaosCrystal = preload("res://Scenes/Items/ChaosCrystal.tscn")

# ============================================
# CONSTANTS
# ============================================
const MIN_OVERLAP_DISTANCE: float = 100.0
const OVERLAP_PUSH_STRENGTH: float = 400.0
const DEFAULT_KNOCKBACK_POWER: float = 600.0
const KNOCKBACK_DECAY_RATE: float = 10.0
const KNOCKBACK_MIN_THRESHOLD: float = 5.0

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
@export var gold_drop_min: int = 2
@export var gold_drop_max: int = 5

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

# Health bar nodes (auto-detected or set by subclass)
var health_bar: Node2D = null
var health_fill: ColorRect = null

# Elite system
var elite_modifier: EliteModifier = null
var is_elite: bool = false

# Status effects
var status_effects: StatusEffects = null

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

func _on_damage_taken():
	# Override for specific damage effects (flash, squash, etc.)
	pass

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

	if health_bar.visible:
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

func take_damage(amount: float, from_position: Vector2 = Vector2.ZERO, knockback_power: float = DEFAULT_KNOCKBACK_POWER, stun_duration: float = 0.0, attacker: Node2D = null):
	if is_dead:
		return

	# Apply elite modifier damage reduction (thorns, shield, etc.)
	var final_damage = amount
	if elite_modifier and is_elite:
		final_damage = elite_modifier.on_take_damage(amount, attacker)

	current_health -= final_damage
	health_changed.emit(current_health, max_health)

	# Check for death first - don't apply hitstun to dead enemies
	if current_health <= 0:
		# Show health bar and damage number before death
		show_health_bar()
		_spawn_damage_number(final_damage)
		die()
		return

	# Show health bar when damaged
	show_health_bar()

	# Spawn damage number
	_spawn_damage_number(final_damage)

	# Apply knockback (only if alive)
	if from_position != Vector2.ZERO:
		var knockback_direction = (global_position - from_position).normalized()
		knockback_velocity = knockback_direction * (knockback_power * (1.0 - knockback_resistance))

	# Apply hitstun (only if alive)
	if stun_duration > 0:
		hitstun_timer = stun_duration

	# Visual feedback (subclass override)
	_on_damage_taken()

func _spawn_damage_number(damage_amount: float):
	var damage_number = DamageNumber.instantiate()
	damage_number.global_position = global_position
	get_tree().current_scene.add_child(damage_number)
	damage_number.setup(damage_amount)

# ============================================
# DEATH SYSTEM (Consolidated)
# ============================================
func die():
	is_dead = true
	enemy_died.emit(self)

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

	# Fade out health bar
	if health_bar:
		var tween = create_tween()
		tween.tween_property(health_bar, "modulate:a", 0.0, 0.3)

	# Call subclass death handler
	_on_death()

func _create_death_particles():
	var particle_count = _get_death_particle_count()
	var particle_color = _get_death_particle_color()

	for i in range(particle_count):
		var particle = ColorRect.new()
		particle.size = Vector2(16, 16)
		particle.position = Vector2(randf_range(-32, 32), randf_range(-32, 32))
		particle.color = particle_color
		add_child(particle)

		var particle_tween = create_tween()
		var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		particle_tween.tween_property(particle, "position", particle.position + random_dir * 120, 0.5)
		particle_tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)

func _drop_gold():
	if RunManager:
		var gold_amount = randi_range(gold_drop_min, gold_drop_max)
		RunManager.add_gold(gold_amount)

func _spawn_crystals():
	if randf() > crystal_drop_chance:
		return

	var num_crystals = randi_range(min_crystals, max_crystals)

	for i in range(num_crystals):
		var crystal = ChaosCrystal.instantiate()
		var offset = Vector2(randf_range(-60, 60), randf_range(-60, 60))
		crystal.global_position = global_position + offset
		get_tree().current_scene.call_deferred("add_child", crystal)

func _add_screen_shake(trauma_amount: float):
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(trauma_amount)

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
func apply_status_effect(effect_type: StatusEffects.EffectType, source: Node2D = null, stacks: int = 1):
	if not status_effects:
		status_effects = StatusEffects.new()
		add_child(status_effects)

	status_effects.apply_effect(effect_type, source, stacks)

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

	var tween = flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)
