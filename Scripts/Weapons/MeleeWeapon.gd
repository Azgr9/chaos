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

# Animation timing constants
const DEFAULT_WINDUP_RATIO: float = 0.15   # 15% of duration for windup
const DEFAULT_ACTIVE_RATIO: float = 0.50   # 50% of duration for active
const DEFAULT_RECOVERY_RATIO: float = 0.35 # 35% of duration for recovery

# ============================================
# EXPORTED STATS - Configure per weapon
# ============================================
@export_group("Weapon Stats")
@export var damage: float = 10.0
@export var attack_duration: float = 0.25
@export var attack_cooldown: float = 0.35
@export var swing_arc: float = 150.0
@export var damage_type: DamageTypes.Type = DamageTypes.Type.PHYSICAL

@export_group("Attack Speed Limits")
## Maximum attacks per second this weapon can perform (weapon-specific cap)
@export var max_attacks_per_second: float = 3.0
## Minimum cooldown this weapon can have (hard floor, cannot be reduced below this)
@export var min_cooldown: float = 0.15

@export_group("Hitbox Settings")
## Range of the cone hitbox (how far the attack reaches)
@export var attack_range: float = 100.0
## Angle of the cone hitbox in degrees (full width, e.g., 90 = 45 degrees each side)
@export var attack_cone_angle: float = 90.0
## Inner radius - attacks won't hit enemies closer than this (for some weapons)
@export var attack_inner_radius: float = 0.0

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

@export_group("Animation Settings")
## Enable hit-stop on impact
@export var enable_hit_stop: bool = true
## Custom windup time ratio (0.0 to 1.0)
@export var windup_ratio: float = DEFAULT_WINDUP_RATIO
## Custom active time ratio (0.0 to 1.0)
@export var active_ratio: float = DEFAULT_ACTIVE_RATIO
## Enable animation canceling during recovery
@export var allow_recovery_cancel: bool = true

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
var is_using_skill: bool = false

# Attack speed scaling
var base_attack_cooldown: float = 0.35
const SPEED_BOOST_PER_HIT: float = 0.1

# Animation state tracking
var _is_in_active_frames: bool = false
var _current_attack_data: Dictionary = {}

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
	# Validate required nodes exist
	if not hit_box or not hit_box_collision or not attack_timer:
		push_error("MeleeWeapon: Missing required nodes (HitBox, CollisionShape2D, or AttackTimer)")
		return

	hit_box.area_entered.connect(_on_hit_box_area_entered)
	hit_box.body_entered.connect(_on_hit_box_body_entered)
	attack_timer.timeout.connect(_on_attack_cooldown_finished)

	# Setup collision layers - ensure we can hit portal (layer 4) and enemies (layer 16)
	# Mask 20 = 4 (portal) + 16 (enemies)
	hit_box.collision_mask = 20

	hit_box_collision.disabled = true
	base_attack_cooldown = attack_cooldown

	_setup_visuals()
	_setup_idle_state()

	# Get player reference
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	player_reference = get_tree().get_first_node_in_group("player")

	# Register with animation system
	if CombatAnimationSystem:
		CombatAnimationSystem.register_weapon(self)

	# Call subclass setup
	_weapon_ready()

func _exit_tree():
	# Unregister from animation system
	if CombatAnimationSystem:
		CombatAnimationSystem.unregister_weapon(self)

func _process(delta):
	_update_combo_timer(delta)
	_update_skill_cooldown(delta)
	_scan_cone_hitbox()  # Active cone scanning each frame when attacking
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
	if sprite:
		sprite.color = weapon_color
	visible = true
	modulate.a = 1.0

func _setup_idle_state():
	# Override for custom idle positioning
	if pivot:
		pivot.position = Vector2.ZERO
		pivot.rotation = deg_to_rad(idle_rotation)
	if sprite:
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
	if not skill_ready or is_attacking or is_using_skill:
		return false

	# Check animation system for interruptibility
	if CombatAnimationSystem and not CombatAnimationSystem.is_interruptible(self):
		return false

	skill_ready = false
	skill_timer = skill_cooldown
	is_using_skill = true
	skill_used.emit(skill_cooldown)
	skill_ready_changed.emit(false)

	# Make player invulnerable during skill
	_start_skill_invulnerability()

	# Update animation state
	if CombatAnimationSystem:
		CombatAnimationSystem.request_transition(self, CombatAnimationSystem.AnimState.SKILL_ACTIVE, true)

	# Perform the skill - if it's async, it should call _end_skill_invulnerability() when done
	# For sync skills, we end invulnerability immediately after
	var success = _perform_skill()

	# For sync skills (non-async), end invulnerability immediately
	# Async skills should override and call _end_skill_invulnerability() themselves
	if not _is_async_skill():
		_end_skill_invulnerability()

	return success

## Override this in subclasses that have async skills (skills with await)
## Return true if the skill uses await and manages its own invulnerability timing
func _is_async_skill() -> bool:
	return false

## Call this when skill animation/effect is complete to end invulnerability
## For sync skills, this is called automatically
## For async skills (with await), call this manually at the end of the skill
func _end_skill_invulnerability():
	is_using_skill = false
	if player_reference and player_reference.has_method("set_invulnerable"):
		player_reference.set_invulnerable(false)

## Use this for async skills that need to manage invulnerability duration manually
## Returns true if invulnerability was started successfully
func _start_skill_invulnerability() -> bool:
	is_using_skill = true
	if player_reference and player_reference.has_method("set_invulnerable"):
		player_reference.set_invulnerable(true)
		return true
	return false

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

	# Check with AttackSpeedSystem if we can attack
	if AttackSpeedSystem and not AttackSpeedSystem.can_attack(self):
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

	# Calculate attack speed based on combo (applies bonus, but system enforces cap)
	var speed_multiplier = 1.0 + (min(combo_count - 1, 2) * SPEED_BOOST_PER_HIT)
	var modified_duration = attack_duration / speed_multiplier

	# Get effective cooldown from AttackSpeedSystem (respects all caps)
	var modified_cooldown: float
	if AttackSpeedSystem:
		modified_cooldown = AttackSpeedSystem.get_effective_cooldown(self, base_attack_cooldown / speed_multiplier)
		# Register this attack with the system
		AttackSpeedSystem.register_attack(self)
	else:
		# Fallback if system not available
		modified_cooldown = base_attack_cooldown / speed_multiplier

	# Enforce weapon's minimum cooldown (hard floor)
	modified_cooldown = maxf(modified_cooldown, min_cooldown)

	# Check for dash attack
	var is_dash_attack = player_reference and is_instance_valid(player_reference) and player_reference.is_dashing

	# Get attack pattern and perform
	var attack_index = get_attack_in_combo()
	var pattern = _get_attack_pattern(attack_index)

	_perform_attack_animation(pattern, modified_duration, is_dash_attack)

	# Start cooldown
	attack_timer.start(modified_cooldown)

	return true

func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	# Kill existing tween and clean up state
	if active_attack_tween:
		active_attack_tween.kill()
		active_attack_tween = null
		# Ensure hitbox is disabled if previous attack was interrupted
		hit_box_collision.set_deferred("disabled", true)
		_is_in_active_frames = false

	var is_finisher = is_combo_finisher()

	# Store attack data for animation system
	_current_attack_data = {
		"pattern": pattern,
		"duration": duration,
		"is_dash_attack": is_dash_attack,
		"is_finisher": is_finisher,
		"windup_time": duration * windup_ratio,
		"active_time": duration * active_ratio,
		"recovery_time": duration * (1.0 - windup_ratio - active_ratio)
	}

	# Register animation state with state machine (tracking only, no tween created)
	if CombatAnimationSystem:
		CombatAnimationSystem.start_animation(
			self,
			CombatAnimationSystem.AnimState.WINDUP,
			duration,
			_current_attack_data
		)

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
	active_attack_tween = TweenHelper.new_tween()

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
	active_attack_tween = TweenHelper.new_tween()

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
	active_attack_tween = TweenHelper.new_tween()

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
	tween.tween_callback(_finish_attack_callback)

func _finish_attack_callback():
	# Named callback function to avoid lambda capture issues
	if is_instance_valid(self):
		finish_attack()

func _enable_hitbox(is_finisher: bool, is_dash: bool):
	hit_box_collision.disabled = false
	_is_in_active_frames = true
	_create_swing_trail(is_finisher, is_dash)

	# Transition to ACTIVE state
	if CombatAnimationSystem:
		CombatAnimationSystem.request_transition(self, CombatAnimationSystem.AnimState.ACTIVE, true)

func _disable_hitbox():
	hit_box_collision.disabled = true
	_is_in_active_frames = false

	# Transition to RECOVERY state
	if CombatAnimationSystem:
		CombatAnimationSystem.request_transition(self, CombatAnimationSystem.AnimState.RECOVERY, true)

func finish_attack():
	if active_attack_tween:
		active_attack_tween.kill()
		active_attack_tween = null

	hit_box_collision.set_deferred("disabled", true)
	is_attacking = false
	_is_in_active_frames = false
	_current_attack_data.clear()

	# Transition to IDLE state
	if CombatAnimationSystem:
		CombatAnimationSystem.finish_animation(self)

	_setup_idle_state()
	sprite.color = weapon_color
	attack_finished.emit()

## Check if currently in active attack frames (hitbox enabled)
func is_in_active_frames() -> bool:
	return _is_in_active_frames

## Check if attack can be canceled (during recovery)
func can_cancel_attack() -> bool:
	if not allow_recovery_cancel:
		return false
	if CombatAnimationSystem:
		var state = CombatAnimationSystem.get_state(self)
		return state == CombatAnimationSystem.AnimState.RECOVERY
	return not is_attacking

func _on_attack_cooldown_finished():
	can_attack = true

# ============================================
# HIT DETECTION - CONE BASED (ACTIVE SCANNING)
# ============================================

## Active cone scanning - called every frame during attack
func _scan_cone_hitbox():
	# Only scan when hitbox is active (during attack active frames)
	if not _is_in_active_frames:
		return

	if not player_reference or not is_instance_valid(player_reference):
		return

	# Scan all enemies in range
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy in hits_this_swing:
			continue
		if not enemy.has_method("take_damage"):
			continue

		# Check if enemy is in attack cone
		if _is_in_attack_cone(enemy.global_position):
			_process_hit(enemy)

	# Also scan for portals and other damageable areas
	var portals = get_tree().get_nodes_in_group("portal")
	for portal in portals:
		if not is_instance_valid(portal):
			continue
		if portal in hits_this_swing:
			continue
		if not portal.has_method("take_damage"):
			continue

		if _is_in_attack_cone(portal.global_position):
			_process_hit(portal)

## Check if a position is within the attack cone
## Cone is ALWAYS fixed to the attack direction (where mouse was when attack started)
## Animation is purely visual - hitbox stays locked to attack direction
## Also accounts for enemy radius to detect edge hits
func _is_in_attack_cone(target_pos: Vector2) -> bool:
	if not player_reference or not is_instance_valid(player_reference):
		return false

	var origin = player_reference.global_position
	var to_target = target_pos - origin
	var distance = to_target.length()

	# Enemy hitbox radius - enemies aren't points, they have size
	# This allows hits when the cone edge touches the enemy's edge
	const ENEMY_RADIUS: float = 25.0

	# Check distance bounds - account for enemy radius
	# Enemy can be hit if their edge is within range
	if distance > attack_range + ENEMY_RADIUS:
		return false

	# Inner radius check only if explicitly set (for special weapons)
	if attack_inner_radius > 0.0 and distance < attack_inner_radius - ENEMY_RADIUS:
		return false

	# Attack angle is ALWAYS based on current_attack_direction
	# This is set when the attack starts (mouse direction at click time)
	# Animation is purely visual - the hitbox cone stays fixed
	var attack_angle: float = current_attack_direction.angle()

	# Check angle - is target within cone?
	# Add extra angle margin based on enemy radius at this distance
	var half_cone = deg_to_rad(attack_cone_angle / 2.0)
	var angle_to_target = to_target.angle()

	# Calculate angular margin from enemy radius
	# At closer distances, the same radius covers more angle
	var angle_margin: float = 0.0
	if distance > 0:
		angle_margin = atan2(ENEMY_RADIUS, distance)

	# Calculate angle difference (handle wrap-around)
	var angle_diff = abs(angle_difference(attack_angle, angle_to_target))

	# Target is in cone if angle difference is within half_cone + margin
	return angle_diff <= half_cone + angle_margin

func _on_hit_box_area_entered(area: Area2D):
	# Backup collision detection (in addition to active scanning)
	if area.has_method("take_damage"):
		_process_hit(area)
	else:
		_process_hit(area.get_parent())

func _on_hit_box_body_entered(body: Node2D):
	_process_hit(body)

func _process_hit(target: Node2D):
	if not is_instance_valid(target):
		return

	if target in hits_this_swing:
		return

	if not target.has_method("take_damage"):
		return

	# Don't hit converted minions (NecroStaff allies)
	if target.is_in_group("converted_minion") or target.is_in_group("player_minions"):
		return

	# Cone hitbox check - verify target is within attack cone
	if not _is_in_attack_cone(target.global_position):
		return

	hits_this_swing.append(target)
	var final_damage = _calculate_damage(target)

	# Extend combo timer on hit
	extend_combo_timer()

	# Calculate knockback
	var is_finisher = is_combo_finisher()
	var knockback_power = finisher_knockback if is_finisher else base_knockback
	var knockback_origin = player_reference.global_position if player_reference and is_instance_valid(player_reference) else global_position

	# Apply damage
	target.take_damage(final_damage, knockback_origin, knockback_power, knockback_stun, player_reference, damage_type)
	dealt_damage.emit(target, final_damage)

	# Emit combat events via CombatEventBus
	var is_crit = _was_last_hit_crit
	var is_dash = player_reference and is_instance_valid(player_reference) and player_reference.is_dashing
	if CombatEventBus:
		CombatEventBus.emit_damage(player_reference, target, final_damage, 0, is_crit, is_finisher, is_dash, knockback_power, self)

	# Visual feedback
	_create_hit_effect(is_finisher, is_crit)
	_create_impact_particles(target.global_position, is_finisher, is_crit)

	# Trigger hit-stop through animation system
	if enable_hit_stop and CombatAnimationSystem:
		var hit_type = _get_hit_stop_type(is_finisher, is_crit)
		CombatAnimationSystem.trigger_hit_stop_for_attack(hit_type)
	elif is_finisher or is_crit:
		# Fallback: weapon shake if no animation system
		_do_weapon_shake()

	# Trigger combo finisher bonus effect
	if is_finisher:
		_on_combo_finisher_hit(target)

## Determine hit-stop type based on attack characteristics
func _get_hit_stop_type(is_finisher: bool, is_crit: bool) -> String:
	if is_crit:
		return "critical"
	elif is_finisher:
		return "finisher"
	elif player_reference and is_instance_valid(player_reference) and player_reference.is_dashing:
		return "heavy"
	else:
		return "medium"

var _was_last_hit_crit: bool = false

func _calculate_damage(target: Node2D) -> float:
	var final_damage = damage * damage_multiplier
	_was_last_hit_crit = false

	# Combo finisher bonus
	if is_combo_finisher():
		final_damage *= combo_finisher_multiplier

	# Dash attack bonus
	if player_reference and is_instance_valid(player_reference) and player_reference.is_dashing:
		final_damage *= DEFAULT_DASH_ATTACK_MULTIPLIER

	# Critical hit
	if player_reference and is_instance_valid(player_reference) and player_reference.stats:
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

	var tween = TweenHelper.new_parallel_tween()
	tween.tween_property(sprite, "color", weapon_color, 0.1)
	tween.tween_property(sprite, "scale", original_scale, 0.15)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _create_impact_particles(hit_position: Vector2, is_finisher: bool, is_crit: bool):
	var particle_count = 8 if (is_finisher or is_crit) else 4
	var particle_color = _get_hit_color(is_finisher, false, is_crit)
	var size = 24.0 if (is_finisher or is_crit) else 16.0
	var distance = 120.0 if (is_finisher or is_crit) else 80.0

	TweenHelper.create_particle_burst(hit_position, particle_count, particle_color, Vector2(size, size), distance, 0.3)

func _spawn_crit_text(spawn_position: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	var label = Label.new()
	label.text = "CRIT!"
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color.RED
	scene.add_child(label)
	label.global_position = spawn_position + Vector2(-80, -120)

	var tween = TweenHelper.new_tween()
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

	var tween = TweenHelper.new_tween()
	tween.tween_property(pivot, "position", original_pos + Vector2(shake_amount, 0), 0.02)
	tween.tween_property(pivot, "position", original_pos + Vector2(-shake_amount, 0), 0.02)
	tween.tween_property(pivot, "position", original_pos + Vector2(shake_amount * 0.5, 0), 0.02)
	tween.tween_property(pivot, "position", original_pos, 0.02)

func _create_swing_trail(is_finisher: bool, is_dash: bool):
	var trail_count = 5 if (is_finisher or is_dash) else 3

	for i in range(trail_count):
		await get_tree().create_timer(0.02).timeout

		# Check if self is still valid after await
		if not is_instance_valid(self):
			return

		var scene = get_tree().current_scene
		if not scene:
			return

		var trail = ColorRect.new()
		trail.size = sprite.size

		if is_finisher:
			trail.color = Color.GOLD.darkened(0.2)
		elif is_dash:
			trail.color = Color.CYAN.darkened(0.2)
		else:
			trail.color = Color(0.8, 0.8, 1.0, 0.4)

		scene.add_child(trail)
		trail.global_position = sprite.global_position
		trail.rotation = pivot.rotation
		trail.scale = sprite.scale

		TweenHelper.scale_fade_free(trail, trail.scale * 1.3, 0.2)
