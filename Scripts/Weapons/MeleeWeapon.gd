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
## Range of the cone hitbox (how far the attack reaches). If 0, auto-calculated from sprite size.
@export var attack_range: float = 0.0
## Angle of the cone hitbox in degrees (full width, e.g., 90 = 45 degrees each side)
@export var attack_cone_angle: float = 90.0
## Inner radius - attacks won't hit enemies closer than this (for some weapons)
@export var attack_inner_radius: float = 0.0

@export_group("Visual Settings")
@export var weapon_length: float = 80.0
@export var idle_rotation: float = 45.0  # Degrees
@export var idle_scale: Vector2 = Vector2(0.6, 0.6)
@export var idle_position: Vector2 = Vector2.ZERO  # Offset from player center
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

@export_group("Walk Animation")
## Enable weapon bob/sway while walking
@export var enable_walk_animation: bool = true
## How much the weapon bobs up/down (pixels)
@export var walk_bob_amount: float = 8.0
## How much the weapon sways (degrees)
@export var walk_sway_amount: float = 12.0
## Walk animation speed multiplier (higher = faster bob)
@export var walk_anim_speed: float = 1.0

# Trail system
var _active_trail: Line2D = null
var _trail_points: Array[Vector2] = []
var _trail_shader_material: ShaderMaterial = null
const TRAIL_MAX_POINTS: int = 20
const TRAIL_FADE_SPEED: float = 6.0
var _line_trail_shader: Shader = preload("res://Shaders/Weapons/LineTrail.gdshader")

# ============================================
# NODES - Expected in scene tree
# ============================================
@onready var pivot: Node2D = $Pivot
@onready var sprite: CanvasItem = $Pivot/Sprite  # Can be ColorRect or Sprite2D
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

# Walk animation state
var _walk_anim_time: float = 0.0
var _last_player_pos: Vector2 = Vector2.ZERO
var _is_player_moving: bool = false

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
	# Render behind player
	z_index = -1

	# Validate required nodes exist
	if not attack_timer:
		push_error("MeleeWeapon: Missing required node (AttackTimer)")
		return

	attack_timer.timeout.connect(_on_attack_cooldown_finished)
	base_attack_cooldown = attack_cooldown

	_setup_visuals()
	_setup_idle_state()

	# Get player reference
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	player_reference = get_tree().get_first_node_in_group("player")

	# Initialize walk animation tracking position
	if player_reference and is_instance_valid(player_reference):
		_last_player_pos = player_reference.global_position

	# Register with animation system
	if CombatAnimationSystem:
		CombatAnimationSystem.register_weapon(self)

	# Call subclass setup
	_weapon_ready()

	# Auto-calculate hitbox based on weapon size
	_calculate_hitbox_from_size()

func _exit_tree():
	# Unregister from animation system
	if CombatAnimationSystem:
		CombatAnimationSystem.unregister_weapon(self)

func _process(delta):
	_update_combo_timer(delta)
	_update_skill_cooldown(delta)
	_scan_cone_hitbox()  # Active cone scanning each frame when attacking
	_update_swing_trail()  # Update weapon trail
	_update_walk_animation(delta)  # Weapon bob/sway while walking
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
		pivot.position = idle_position
		pivot.rotation = deg_to_rad(idle_rotation)
	if sprite:
		sprite.scale = idle_scale

func _calculate_hitbox_from_size():
	# Auto-calculate attack_range based on actual sprite size
	# Only calculate if attack_range is 0 (not manually set in scene)
	if attack_range <= 0.0:
		var max_reach: float = 0.0

		# Check ColorRect sprite (base Sprite node)
		if sprite and sprite.visible:
			if sprite is ColorRect:
				# ColorRect uses offset system - calculate height
				var height = abs(sprite.offset_bottom - sprite.offset_top)
				max_reach = max(max_reach, height * sprite.scale.y)
			elif sprite is Sprite2D and sprite.texture:
				var tex_size = sprite.texture.get_size()
				max_reach = max(max_reach, tex_size.y * sprite.scale.y)

		# Check for Sprite2D children in Pivot (texture-based weapons)
		if pivot:
			for child in pivot.get_children():
				if child is Sprite2D and child.visible and child.texture:
					var tex_size = child.texture.get_size()
					# Sprite position + half texture height (scaled)
					var sprite_reach = abs(child.position.y) + (tex_size.y * child.scale.y * 0.5)
					max_reach = max(max_reach, sprite_reach)
				elif child is ColorRect and child.visible:
					var height = abs(child.offset_bottom - child.offset_top)
					max_reach = max(max_reach, height * child.scale.y)

		# Set attack_range to sprite reach (with buffer for better feel)
		if max_reach > 0:
			attack_range = max_reach * 1.25  # 25% buffer for better hit detection
		else:
			# Fallback to weapon_length if no sprite found
			attack_range = weapon_length

	# Debug output
	# print("%s - attack_range: %.1f" % [name, attack_range])

func _update_walk_animation(delta: float):
	# Skip if disabled, attacking, or using skill
	if not enable_walk_animation or is_attacking or is_using_skill:
		if _walk_anim_time != 0.0:
			_walk_anim_time = 0.0
			_reset_walk_animation()
		return

	if not player_reference or not is_instance_valid(player_reference):
		return

	var current_pos = player_reference.global_position
	var velocity = (current_pos - _last_player_pos) / max(delta, 0.001)
	_last_player_pos = current_pos

	var speed = velocity.length()
	_is_player_moving = speed > 5.0

	if not _is_player_moving:
		# Smoothly return to idle
		if _walk_anim_time != 0.0:
			_walk_anim_time = lerpf(_walk_anim_time, 0.0, delta * 6.0)
			if abs(_walk_anim_time) < 0.01:
				_walk_anim_time = 0.0
				_reset_walk_animation()
			else:
				_apply_walk_animation()
		return

	# Update animation time
	var anim_speed = 10.0 * walk_anim_speed
	_walk_anim_time += delta * anim_speed
	_apply_walk_animation()

func _apply_walk_animation():
	if not pivot:
		return

	# Simple bob and sway
	var bob_offset = sin(_walk_anim_time * 2.0) * walk_bob_amount
	var sway_rotation = sin(_walk_anim_time) * walk_sway_amount

	# Apply to pivot
	pivot.position = idle_position + Vector2(0, bob_offset)
	pivot.rotation = deg_to_rad(idle_rotation + sway_rotation)

func _reset_walk_animation():
	if not pivot:
		return
	# Reset to idle state
	pivot.position = idle_position
	pivot.rotation = deg_to_rad(idle_rotation)

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

	# Reset animation state to IDLE so next skill can be used
	if CombatAnimationSystem:
		CombatAnimationSystem.request_transition(self, CombatAnimationSystem.AnimState.IDLE, true)

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
	_is_in_active_frames = true
	_create_swing_trail(is_finisher, is_dash)

	# Transition to ACTIVE state
	if CombatAnimationSystem:
		CombatAnimationSystem.request_transition(self, CombatAnimationSystem.AnimState.ACTIVE, true)

func _disable_hitbox():
	_is_in_active_frames = false

	# Transition to RECOVERY state
	if CombatAnimationSystem:
		CombatAnimationSystem.request_transition(self, CombatAnimationSystem.AnimState.RECOVERY, true)

func finish_attack():
	if active_attack_tween:
		active_attack_tween.kill()
		active_attack_tween = null

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

	# Also scan for targetable objects (portals, destructibles, etc.)
	var targetables = get_tree().get_nodes_in_group("targetable")
	for target in targetables:
		if not is_instance_valid(target):
			continue
		if target in hits_this_swing:
			continue
		if not target.has_method("take_damage"):
			continue

		if _is_in_attack_cone(target.global_position):
			_process_hit(target)

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
	# Create Line2D trail that follows weapon tip with shader
	_trail_points.clear()

	if _active_trail and is_instance_valid(_active_trail):
		_active_trail.queue_free()

	var scene = get_tree().current_scene
	if not scene:
		return

	_active_trail = Line2D.new()
	_active_trail.width = 40.0 if (is_finisher or is_dash) else 28.0
	_active_trail.default_color = Color.WHITE  # Shader handles color
	_active_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_active_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_active_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_active_trail.texture_mode = Line2D.LINE_TEXTURE_STRETCH

	# Width curve - thick at newest point, thin at oldest
	var width_curve = Curve.new()
	width_curve.add_point(Vector2(0.0, 0.0))  # Old end - thin
	width_curve.add_point(Vector2(0.3, 0.4))
	width_curve.add_point(Vector2(0.7, 0.8))
	width_curve.add_point(Vector2(1.0, 1.0))  # New end - thick
	_active_trail.width_curve = width_curve

	# Apply shader material
	_trail_shader_material = ShaderMaterial.new()
	_trail_shader_material.shader = _line_trail_shader

	var trail_color = _get_trail_color(is_finisher, is_dash)
	var glow_color = _get_glow_color(is_finisher, is_dash)
	var glow_intensity = 3.0 if is_finisher else (2.5 if is_dash else 2.0)

	_trail_shader_material.set_shader_parameter("trail_color", trail_color)
	_trail_shader_material.set_shader_parameter("glow_color", glow_color)
	_trail_shader_material.set_shader_parameter("glow_intensity", glow_intensity)
	_trail_shader_material.set_shader_parameter("core_sharpness", 0.6)
	_trail_shader_material.set_shader_parameter("shimmer_speed", 5.0 if is_finisher else 3.0)
	_trail_shader_material.set_shader_parameter("shimmer_amount", 0.4 if is_finisher else 0.2)

	_active_trail.material = _trail_shader_material

	scene.add_child(_active_trail)

func _get_trail_color(is_finisher: bool, is_dash: bool) -> Color:
	if is_finisher:
		return Color(1.0, 0.85, 0.2, 0.95)  # Gold
	elif is_dash:
		return Color(0.2, 0.8, 1.0, 0.95)  # Cyan
	else:
		return Color(weapon_color.r, weapon_color.g, weapon_color.b, 0.9)

func _get_glow_color(is_finisher: bool, is_dash: bool) -> Color:
	if is_finisher:
		return Color(1.0, 1.0, 0.6, 1.0)  # Bright yellow
	elif is_dash:
		return Color(0.6, 1.0, 1.0, 1.0)  # Bright cyan
	else:
		return Color(1.0, 1.0, 1.0, 1.0)  # White

func _get_weapon_tip_position() -> Vector2:
	if not pivot or not sprite:
		return global_position
	# Calculate weapon tip based on pivot rotation and weapon length
	var tip_offset = Vector2(0, -weapon_length).rotated(pivot.rotation)
	return global_position + tip_offset

func _update_swing_trail():
	if not _active_trail or not is_instance_valid(_active_trail):
		return

	if not _is_in_active_frames:
		# Fade out trail when attack ends
		if _active_trail.modulate.a > 0:
			_active_trail.modulate.a -= get_process_delta_time() * TRAIL_FADE_SPEED
			if _active_trail.modulate.a <= 0:
				_active_trail.queue_free()
				_active_trail = null
				_trail_points.clear()
		return

	# Add current weapon tip position
	var tip_pos = _get_weapon_tip_position()
	_trail_points.append(tip_pos)

	# Limit trail length
	while _trail_points.size() > TRAIL_MAX_POINTS:
		_trail_points.remove_at(0)

	# Update Line2D points
	_active_trail.clear_points()
	for point in _trail_points:
		_active_trail.add_point(point)
