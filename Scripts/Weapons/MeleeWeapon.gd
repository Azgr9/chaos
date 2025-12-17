# SCRIPT: MeleeWeapon.gd
# BASE CLASS: All melee weapons inherit from this
# LOCATION: res://Scripts/Weapons/MeleeWeapon.gd

class_name MeleeWeapon
extends Node2D

# ============================================
# CONSTANTS - Override in subclasses as needed
# ============================================
const DEFAULT_COMBO_WINDOW: float = 1.5
const DEFAULT_COMBO_EXTENSION: float = 0.5
const DEFAULT_COMBO_FINISHER_MULTIPLIER: float = 1.5
const DEFAULT_BASE_KNOCKBACK: float = 400.0
const DEFAULT_FINISHER_KNOCKBACK: float = 800.0
const DEFAULT_KNOCKBACK_STUN: float = 0.15
const DEFAULT_CRIT_MULTIPLIER: float = 2.0
const DEFAULT_DASH_ATTACK_MULTIPLIER: float = 1.5

# ============================================
# EXPORTED STATS - Configure per weapon
# ============================================
@export_group("Weapon Stats")
@export var damage: float = 10.0
@export var attack_duration: float = 0.25
@export var attack_cooldown: float = 0.35
@export var swing_arc: float = 150.0

@export_group("Visual Settings")
@export var weapon_length: float = 80.0
@export var idle_rotation: float = 45.0  # Degrees
@export var idle_scale: Vector2 = Vector2(0.6, 0.6)
@export var weapon_color: Color = Color("#c0c0c0")

@export_group("Combo Settings")
@export var combo_window: float = DEFAULT_COMBO_WINDOW
@export var combo_extension_on_hit: float = DEFAULT_COMBO_EXTENSION
@export var combo_finisher_multiplier: float = DEFAULT_COMBO_FINISHER_MULTIPLIER
@export var combo_hits: int = 3  # Number of hits in combo cycle

@export_group("Knockback Settings")
@export var base_knockback: float = DEFAULT_BASE_KNOCKBACK
@export var finisher_knockback: float = DEFAULT_FINISHER_KNOCKBACK
@export var knockback_stun: float = DEFAULT_KNOCKBACK_STUN

@export_group("Skill Settings")
@export var skill_cooldown: float = 8.0
@export var skill_scene: PackedScene  # Override in subclass

# ============================================
# NODES - Expected in scene tree
# ============================================
@onready var pivot: Node2D = $Pivot
@onready var sprite: ColorRect = $Pivot/Sprite
@onready var hit_box: Area2D = $Pivot/HitBox
@onready var hit_box_collision: CollisionShape2D = $Pivot/HitBox/CollisionShape2D
@onready var attack_timer: Timer = $AttackTimer

# ============================================
# STATE
# ============================================
var is_attacking: bool = false
var can_attack: bool = true
var damage_multiplier: float = 1.0
var hits_this_swing: Array = []
var active_attack_tween: Tween = null
var player_reference: Node2D = null
var current_attack_direction: Vector2 = Vector2.RIGHT  # Track attack direction for animations

# Combo state
var combo_count: int = 0
var combo_timer: float = 0.0

# Skill state
var skill_ready: bool = true
var skill_timer: float = 0.0

# Attack speed scaling
var base_attack_cooldown: float = 0.35
const SPEED_BOOST_PER_HIT: float = 0.1

# ============================================
# SIGNALS
# ============================================
signal attack_finished
signal dealt_damage(target: Node2D, damage: float)
signal skill_used(cooldown: float)
signal skill_ready_changed(ready: bool)

# ============================================
# LIFECYCLE
# ============================================
func _ready():
	hit_box.area_entered.connect(_on_hit_box_area_entered)
	hit_box.body_entered.connect(_on_hit_box_body_entered)
	attack_timer.timeout.connect(_on_attack_cooldown_finished)

	hit_box_collision.disabled = true
	base_attack_cooldown = attack_cooldown

	_setup_visuals()
	_setup_idle_state()

	# Get player reference
	await get_tree().process_frame
	player_reference = get_tree().get_first_node_in_group("player")

	# Call subclass setup
	_weapon_ready()

func _process(delta):
	_update_combo_timer(delta)
	_update_skill_cooldown(delta)
	_weapon_process(delta)

# ============================================
# VIRTUAL METHODS - Override in subclasses
# ============================================
func _weapon_ready():
	# Override for weapon-specific setup
	pass

func _weapon_process(_delta):
	# Override for weapon-specific per-frame logic
	pass

func _setup_visuals():
	# Override for custom visual setup
	sprite.color = weapon_color
	visible = true
	modulate.a = 1.0

func _setup_idle_state():
	# Override for custom idle positioning
	pivot.position = Vector2.ZERO
	pivot.rotation = deg_to_rad(idle_rotation)
	sprite.scale = idle_scale

func _get_attack_pattern(attack_index: int) -> String:
	# Override to define combo attack sequence
	# Simple 3-hit combo: left-right, right-left, left-right
	match attack_index:
		1: return "horizontal"           # Left to right
		2: return "horizontal_reverse"   # Right to left
		3: return "horizontal"           # Left to right (finisher)
		_: return "horizontal"

func _perform_skill() -> bool:
	# Override for weapon-specific skill
	return false

func _on_combo_finisher_hit(_target: Node2D):
	# Override in subclasses for weapon-specific combo finisher effects
	# e.g., BasicSword creates shockwave, Katana resets dash
	pass

func _get_hit_color(combo_finisher: bool, dash_attack: bool, crit: bool) -> Color:
	if crit:
		return Color.RED
	elif combo_finisher:
		return Color.GOLD
	elif dash_attack:
		return Color.CYAN
	return weapon_color

# ============================================
# COMBO SYSTEM
# ============================================
func _update_combo_timer(delta):
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0

func get_attack_in_combo() -> int:
	if combo_hits <= 0:
		return 1
	return ((combo_count - 1) % combo_hits) + 1

func is_combo_finisher() -> bool:
	return get_attack_in_combo() == combo_hits

func extend_combo_timer():
	combo_timer += combo_extension_on_hit

# ============================================
# SKILL SYSTEM
# ============================================
func _update_skill_cooldown(delta):
	if not skill_ready:
		skill_timer -= delta
		if skill_timer <= 0:
			skill_ready = true
			skill_ready_changed.emit(true)

func use_skill() -> bool:
	if not skill_ready or is_attacking:
		return false

	skill_ready = false
	skill_timer = skill_cooldown
	skill_used.emit(skill_cooldown)
	skill_ready_changed.emit(false)

	return _perform_skill()

func get_skill_cooldown_percent() -> float:
	if skill_ready:
		return 1.0
	return 1.0 - (skill_timer / skill_cooldown)

# ============================================
# ATTACK SYSTEM
# ============================================
func attack(direction: Vector2, player_damage_multiplier: float = 1.0) -> bool:
	if not can_attack or is_attacking:
		return false

	# Set flags immediately to prevent race conditions
	can_attack = false
	is_attacking = true

	# Store attack direction for animations
	current_attack_direction = direction.normalized() if direction.length() > 0 else Vector2.RIGHT

	damage_multiplier = player_damage_multiplier
	hits_this_swing.clear()

	# Increment combo
	combo_count += 1
	combo_timer = combo_window

	# Calculate attack speed based on combo
	var speed_multiplier = 1.0 + (min(combo_count - 1, 2) * SPEED_BOOST_PER_HIT)
	var modified_duration = attack_duration / speed_multiplier
	var modified_cooldown = base_attack_cooldown / speed_multiplier

	# Check for dash attack
	var is_dash_attack = player_reference and player_reference.is_dashing

	# Get attack pattern and perform
	var attack_index = get_attack_in_combo()
	var pattern = _get_attack_pattern(attack_index)

	_perform_attack_animation(pattern, modified_duration, is_dash_attack)

	# Start cooldown
	attack_timer.start(modified_cooldown)

	return true

func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	# Kill existing tween
	if active_attack_tween:
		active_attack_tween.kill()

	var is_finisher = is_combo_finisher()

	# Set attack color
	if is_finisher:
		sprite.color = Color.GOLD
	elif is_dash_attack:
		sprite.color = Color.CYAN

	match pattern:
		"horizontal":
			_animate_horizontal_swing(duration, is_dash_attack, false)
		"horizontal_reverse":
			_animate_horizontal_swing(duration, is_dash_attack, true)
		"overhead":
			_animate_overhead_swing(duration, is_dash_attack)
		"stab":
			_animate_stab(duration, is_dash_attack)
		_:
			_animate_horizontal_swing(duration, is_dash_attack, false)

func _animate_horizontal_swing(duration: float, is_dash_attack: bool, reverse: bool):
	active_attack_tween = create_tween()

	# Get the base angle from attack direction
	# The sword sprite points UP (negative Y), so we need to add 90 degrees
	# to make it point in the attack direction
	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	# Simple arc swing: 150 degree total arc centered on attack direction
	var half_arc = 75.0

	var start_angle: float
	var end_angle: float

	if reverse:
		# Right to left
		start_angle = base_angle + half_arc
		end_angle = base_angle - half_arc
	else:
		# Left to right
		start_angle = base_angle - half_arc
		end_angle = base_angle + half_arc

	# Set starting state
	pivot.rotation = deg_to_rad(start_angle)
	pivot.position = Vector2.ZERO
	sprite.scale = Vector2.ONE

	# Anticipation - small wind up
	var windup_angle = start_angle + (-10 if not reverse else 10)
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(windup_angle), duration * 0.15)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(is_combo_finisher(), is_dash_attack))

	# Main swing - fast arc
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(end_angle), duration * 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Follow through
	var followthrough_angle = end_angle + (10 if not reverse else -10)
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(followthrough_angle), duration * 0.2)

	# Disable hitbox and return to idle
	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _animate_overhead_swing(duration: float, is_dash_attack: bool):
	active_attack_tween = create_tween()

	# Get the base angle from attack direction (add 90 for sprite orientation)
	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	# Third hit: same arc pattern, slightly wider for finisher feel
	var half_arc = 85.0

	# Left to right (same as first hit)
	var start_angle = base_angle - half_arc
	var end_angle = base_angle + half_arc

	pivot.rotation = deg_to_rad(start_angle)
	pivot.position = Vector2.ZERO
	sprite.scale = Vector2.ONE

	# Anticipation - wind up
	var windup_angle = start_angle - 15
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(windup_angle), duration * 0.15)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(is_combo_finisher(), is_dash_attack))

	# Main swing - powerful arc
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(end_angle), duration * 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Follow through - extra for finisher
	var followthrough_angle = end_angle + 20
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(followthrough_angle), duration * 0.2)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _animate_stab(duration: float, _is_dash_attack: bool):
	active_attack_tween = create_tween()

	# Get the base angle (add 90 for sprite orientation)
	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	# Stab: point at target and thrust forward
	pivot.rotation = deg_to_rad(base_angle)
	pivot.position = Vector2.ZERO
	sprite.scale = Vector2.ONE

	# Pull back slightly
	var pullback_pos = current_attack_direction * -30
	active_attack_tween.tween_property(pivot, "position", pullback_pos, duration * 0.15)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(is_combo_finisher(), false))

	# Thrust forward
	var thrust_distance = 80.0 if is_combo_finisher() else 60.0
	var thrust_pos = current_attack_direction * thrust_distance
	active_attack_tween.tween_property(pivot, "position", thrust_pos, duration * 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Return
	active_attack_tween.tween_property(pivot, "position", Vector2.ZERO, duration * 0.3)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _tween_to_idle(tween: Tween):
	tween.tween_property(pivot, "position", Vector2.ZERO, 0.15)
	tween.parallel().tween_property(pivot, "rotation", deg_to_rad(idle_rotation), 0.15)
	tween.parallel().tween_property(sprite, "scale", idle_scale, 0.15)
	tween.tween_callback(finish_attack)

func _enable_hitbox(is_finisher: bool, is_dash: bool):
	hit_box_collision.disabled = false
	_create_swing_trail(is_finisher, is_dash)

func _disable_hitbox():
	hit_box_collision.disabled = true

func finish_attack():
	if active_attack_tween:
		active_attack_tween.kill()
		active_attack_tween = null

	hit_box_collision.set_deferred("disabled", true)
	is_attacking = false

	_setup_idle_state()
	sprite.color = weapon_color
	attack_finished.emit()

func _on_attack_cooldown_finished():
	can_attack = true

# ============================================
# HIT DETECTION
# ============================================
func _on_hit_box_area_entered(area: Area2D):
	_process_hit(area.get_parent())

func _on_hit_box_body_entered(body: Node2D):
	_process_hit(body)

func _process_hit(target: Node2D):
	if target in hits_this_swing:
		return

	if not target.has_method("take_damage"):
		return

	hits_this_swing.append(target)
	var final_damage = _calculate_damage(target)

	# Extend combo timer on hit
	extend_combo_timer()

	# Calculate knockback
	var is_finisher = is_combo_finisher()
	var knockback_power = finisher_knockback if is_finisher else base_knockback
	var knockback_origin = player_reference.global_position if player_reference else global_position

	# Apply damage
	target.take_damage(final_damage, knockback_origin, knockback_power, knockback_stun, player_reference)
	dealt_damage.emit(target, final_damage)

	# Visual feedback
	var is_crit = _was_last_hit_crit
	_create_hit_effect(is_finisher, is_crit)
	_create_impact_particles(target.global_position, is_finisher, is_crit)

	# Brief weapon shake for hitstop feel (no time_scale - it causes issues when player gets hit)
	if is_finisher or is_crit:
		_do_weapon_shake()

	# Trigger combo finisher bonus effect
	if is_finisher:
		_on_combo_finisher_hit(target)

var _was_last_hit_crit: bool = false

func _calculate_damage(target: Node2D) -> float:
	var final_damage = damage * damage_multiplier
	_was_last_hit_crit = false

	# Combo finisher bonus
	if is_combo_finisher():
		final_damage *= combo_finisher_multiplier

	# Dash attack bonus
	if player_reference and player_reference.is_dashing:
		final_damage *= DEFAULT_DASH_ATTACK_MULTIPLIER

	# Critical hit
	if player_reference and player_reference.stats:
		var crit_chance = player_reference.stats.crit_chance
		var crit_mult = player_reference.stats.crit_damage if player_reference.stats.crit_damage > 0 else DEFAULT_CRIT_MULTIPLIER

		if randf() < crit_chance:
			final_damage *= crit_mult
			_was_last_hit_crit = true
			_spawn_crit_text(target.global_position)

	return final_damage

# ============================================
# VISUAL EFFECTS
# ============================================
func _create_hit_effect(is_finisher: bool, is_crit: bool):
	var color = _get_hit_color(is_finisher, false, is_crit)
	sprite.color = color

	var original_scale = sprite.scale
	var squash = 1.6 if (is_finisher or is_crit) else 1.4
	sprite.scale = Vector2(squash, 0.8)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "color", weapon_color, 0.1)
	tween.tween_property(sprite, "scale", original_scale, 0.15)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _create_impact_particles(hit_position: Vector2, is_finisher: bool, is_crit: bool):
	var particle_count = 8 if (is_finisher or is_crit) else 4
	var particle_color = _get_hit_color(is_finisher, false, is_crit)

	for i in range(particle_count):
		var particle = ColorRect.new()
		var size = 24 if (is_finisher or is_crit) else 16
		particle.size = Vector2(size, size)
		particle.color = particle_color
		get_tree().current_scene.add_child(particle)
		particle.global_position = hit_position

		var angle = (TAU / particle_count) * i + randf_range(-0.2, 0.2)
		var direction = Vector2.from_angle(angle)
		var distance = randf_range(80, 140) if (is_finisher or is_crit) else randf_range(60, 100)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", hit_position + direction * distance, 0.3)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_property(particle, "scale", Vector2(0.5, 0.5), 0.3)
		tween.tween_callback(particle.queue_free)

func _spawn_crit_text(spawn_position: Vector2):
	var label = Label.new()
	label.text = "CRIT!"
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color.RED
	get_tree().current_scene.add_child(label)
	label.global_position = spawn_position + Vector2(-80, -120)

	var tween = create_tween()
	tween.tween_property(label, "global_position:y", spawn_position.y - 200, 0.5)
	tween.parallel().tween_property(label, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.3)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func _do_weapon_shake():
	# Quick shake effect for impactful hits (no time_scale manipulation)
	if not pivot:
		return

	var original_pos = pivot.position
	var shake_amount = 3.0

	var tween = create_tween()
	tween.tween_property(pivot, "position", original_pos + Vector2(shake_amount, 0), 0.02)
	tween.tween_property(pivot, "position", original_pos + Vector2(-shake_amount, 0), 0.02)
	tween.tween_property(pivot, "position", original_pos + Vector2(shake_amount * 0.5, 0), 0.02)
	tween.tween_property(pivot, "position", original_pos, 0.02)

func _create_swing_trail(is_finisher: bool, is_dash: bool):
	var trail_count = 5 if (is_finisher or is_dash) else 3

	for i in range(trail_count):
		await get_tree().create_timer(0.02).timeout

		var trail = ColorRect.new()
		trail.size = sprite.size

		if is_finisher:
			trail.color = Color.GOLD.darkened(0.2)
		elif is_dash:
			trail.color = Color.CYAN.darkened(0.2)
		else:
			trail.color = Color(0.8, 0.8, 1.0, 0.4)

		get_tree().current_scene.add_child(trail)
		trail.global_position = sprite.global_position
		trail.rotation = pivot.rotation
		trail.scale = sprite.scale

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(trail, "modulate:a", 0.0, 0.2)
		tween.tween_property(trail, "scale", trail.scale * 1.3, 0.2)
		tween.tween_callback(trail.queue_free)
