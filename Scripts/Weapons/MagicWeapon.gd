# SCRIPT: MagicWeapon.gd
# BASE CLASS: All magic/staff weapons inherit from this
# LOCATION: res://Scripts/Weapons/MagicWeapon.gd

class_name MagicWeapon
extends Node2D

# ============================================
# CONSTANTS
# ============================================
const DEFAULT_BEAM_WIDTH: float = 32.0
const DEFAULT_BEAM_RANGE: float = 800.0

# ============================================
# EXPORTED STATS - Configure per weapon
# ============================================
@export_group("Weapon Stats")
@export var projectile_scene: PackedScene
@export var attack_cooldown: float = 0.3
@export var projectile_spread: float = 0.0  # Degrees of random spread (0 = no spread)
@export var multi_shot: int = 1
@export var damage: float = 10.0
@export var damage_type: DamageTypes.Type = DamageTypes.Type.PHYSICAL

@export_group("Attack Speed Limits")
## Maximum attacks per second this weapon can perform (weapon-specific cap)
@export var max_attacks_per_second: float = 3.5
## Minimum cooldown this weapon can have (hard floor, cannot be reduced below this)
@export var min_cooldown: float = 0.12

@export_group("Visual Settings")
@export var staff_color: Color = Color("#8b4513")
@export var muzzle_flash_color: Color = Color.WHITE

@export_group("Skill Settings")
@export var skill_cooldown: float = 10.0
@export var beam_damage: float = 50.0
@export var beam_range: float = DEFAULT_BEAM_RANGE
@export var beam_width: float = DEFAULT_BEAM_WIDTH

@export_group("Animation Settings")
## Enable hit-stop on skill impact
@export var enable_skill_hit_stop: bool = true

@export_group("Walk Animation")
## Enable weapon bob/sway while walking
@export var enable_walk_animation: bool = true
## How much the weapon bobs up/down (pixels)
@export var walk_bob_amount: float = 4.0
## How much the weapon sways (degrees)
@export var walk_sway_amount: float = 6.0
## Walk animation speed multiplier (higher = faster bob)
@export var walk_anim_speed: float = 1.0

@export_group("Trail Settings")
## Enable casting trail effect
@export var enable_cast_trail: bool = true
## Trail width
@export var trail_width: float = 20.0

# ============================================
# NODES - Expected in scene tree
# ============================================
@onready var sprite: Node2D = $Sprite  # Can be ColorRect or Sprite2D
@onready var projectile_spawn: Marker2D = $ProjectileSpawn
@onready var cooldown_timer: Timer = $AttackCooldown
@onready var muzzle_flash: ColorRect = $MuzzleFlash

# ============================================
# STATE
# ============================================
var can_attack: bool = true
var damage_multiplier: float = 1.0
var player_reference: Node2D = null

# Skill state
var skill_ready: bool = true
var skill_timer: float = 0.0
var is_using_skill: bool = false

# Trail system
var _active_trail: Line2D = null
var _trail_points: Array[Vector2] = []
var _trail_shader_material: ShaderMaterial = null
var _is_casting: bool = false
const TRAIL_MAX_POINTS: int = 16
const TRAIL_FADE_SPEED: float = 5.0
var _magic_trail_shader: Shader = preload("res://Shaders/Weapons/MagicTrail.gdshader")

# Walk animation state
var _walk_anim_time: float = 0.0
var _last_player_pos: Vector2 = Vector2.ZERO
var _is_player_moving: bool = false
var _base_sprite_position: Vector2 = Vector2.ZERO
var _base_sprite_rotation: float = 0.0

# Cached enemy group for efficiency
var _cached_enemies: Array = []
var _cache_frame: int = -1

# ============================================
# SIGNALS
# ============================================
signal projectile_fired(projectile: Area2D)
signal skill_used(cooldown: float)
signal skill_ready_changed(ready: bool)

# ============================================
# LIFECYCLE
# ============================================
func _ready():
	# Render behind player
	z_index = -1

	cooldown_timer.timeout.connect(_on_cooldown_finished)
	muzzle_flash.modulate.a = 0.0

	# Load default projectile if not set
	if not projectile_scene:
		projectile_scene = preload("res://Scenes/Spells/BasicProjectile.tscn")

	# Get player reference
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	player_reference = get_tree().get_first_node_in_group("player")

	# Register with animation system
	if CombatAnimationSystem:
		CombatAnimationSystem.register_weapon(self)

	# Store base sprite position/rotation for walk animation
	if sprite:
		_base_sprite_position = sprite.position
		_base_sprite_rotation = sprite.rotation

	if player_reference:
		_last_player_pos = player_reference.global_position

	_weapon_ready()

func _exit_tree():
	# Unregister from animation system
	if CombatAnimationSystem:
		CombatAnimationSystem.unregister_weapon(self)

func _process(delta):
	_update_skill_cooldown(delta)
	_update_cast_trail()
	_update_walk_animation(delta)
	_correct_projectile_spawn()
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

func _perform_skill() -> bool:
	# Override for weapon-specific skill
	# Default: fire beam
	if not player_reference:
		return false

	var mouse_pos = player_reference.get_global_mouse_position()
	var direction = (mouse_pos - player_reference.global_position).normalized()
	_fire_beam(player_reference.global_position, direction, player_reference.stats.magic_damage_multiplier)
	return true

func _get_projectile_color() -> Color:
	return Color(0.4, 0.8, 1.0)

func _get_beam_color() -> Color:
	return Color(1.0, 1.0, 0.8, 1.0)

func _get_beam_glow_color() -> Color:
	return Color(0.4, 0.8, 1.0, 0.6)

# ============================================
# ENEMY CACHING - Performance optimization
# ============================================
func _get_enemies() -> Array:
	var current_frame = Engine.get_process_frames()
	if _cache_frame != current_frame:
		_cached_enemies = get_tree().get_nodes_in_group("enemies")
		# Also include targetable entities (like QuartersPortal)
		_cached_enemies.append_array(get_tree().get_nodes_in_group("targetable"))
		_cache_frame = current_frame
	return _cached_enemies

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
	if not skill_ready or is_using_skill:
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
func attack(direction: Vector2, magic_damage_multiplier: float = 1.0) -> bool:
	if not can_attack:
		return false

	# Check with AttackSpeedSystem if we can attack
	if AttackSpeedSystem and not AttackSpeedSystem.can_attack(self):
		return false

	damage_multiplier = magic_damage_multiplier

	_fire_projectiles(direction)
	_play_attack_animation()

	can_attack = false

	# Get effective cooldown from AttackSpeedSystem (respects all caps)
	var effective_cooldown: float
	if AttackSpeedSystem:
		effective_cooldown = AttackSpeedSystem.get_effective_cooldown(self, attack_cooldown)
		# Register this attack with the system
		AttackSpeedSystem.register_attack(self)
	else:
		# Fallback if system not available
		effective_cooldown = attack_cooldown

	# Enforce weapon's minimum cooldown (hard floor)
	effective_cooldown = maxf(effective_cooldown, min_cooldown)

	cooldown_timer.start(effective_cooldown)

	return true

func _fire_projectiles(_direction: Vector2):
	for i in range(multi_shot):
		# Calculate direction from projectile spawn point to mouse for accurate aiming
		var mouse_pos = player_reference.get_global_mouse_position() if player_reference and is_instance_valid(player_reference) else get_global_mouse_position()
		var aim_direction = (mouse_pos - projectile_spawn.global_position).normalized()

		# Calculate spread
		var spread_angle = _calculate_spread_angle(i)
		var final_direction = aim_direction.rotated(spread_angle)

		var projectile: Node2D = null

		# Try to use ProjectilePool if available
		if ProjectilePool:
			var pool_name = _get_projectile_pool_name()
			projectile = ProjectilePool.spawn(
				pool_name,
				projectile_spawn.global_position,
				final_direction,
				damage_multiplier,
				400.0,  # knockback_power
				0.1,    # hitstun_duration
				player_reference,
				damage_type
			)

		# Fallback to direct instantiation
		if not projectile and projectile_scene:
			projectile = projectile_scene.instantiate()
			if projectile:
				get_tree().root.add_child(projectile)
				projectile.initialize(
					projectile_spawn.global_position,
					final_direction,
					damage_multiplier,
					400.0,
					0.1,
					player_reference,
					damage_type
				)

		if not projectile:
			continue

		# Apply custom projectile visuals
		_customize_projectile(projectile)

		projectile_fired.emit(projectile)

## Override in subclasses to specify which pool to use
func _get_projectile_pool_name() -> String:
	# Map damage type to pool name
	match damage_type:
		DamageTypes.Type.FIRE:
			return "projectile_fire"
		DamageTypes.Type.ICE:
			return "projectile_ice"
		DamageTypes.Type.ELECTRIC:
			return "projectile_lightning"
		_:
			return "projectile_basic"

func _customize_projectile(projectile: Node2D):
	# Override in subclasses for unique projectile visuals
	# Default: apply projectile color
	if projectile.has_node("Sprite"):
		projectile.get_node("Sprite").color = _get_projectile_color()

func _calculate_spread_angle(projectile_index: int) -> float:
	if multi_shot > 1:
		var spread_step = deg_to_rad(projectile_spread * 2) / (multi_shot - 1)
		return -deg_to_rad(projectile_spread) + (spread_step * projectile_index)
	else:
		return randf_range(-deg_to_rad(projectile_spread), deg_to_rad(projectile_spread))

func _play_attack_animation():
	# Start cast trail
	_create_cast_trail()

	# Muzzle flash
	muzzle_flash.modulate.a = 1.0
	var flash_tween = TweenHelper.new_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.1)

	# Staff recoil
	var recoil_tween = TweenHelper.new_tween()
	recoil_tween.tween_property(self, "position:x", -12, 0.05)
	recoil_tween.tween_property(self, "position:x", 0, 0.1)

	# Staff glow
	var original_modulate = sprite.modulate
	sprite.modulate = staff_color.lightened(0.3)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(self) and sprite:
		sprite.modulate = original_modulate

	# End cast trail after animation
	_end_cast_trail()

func _on_cooldown_finished():
	can_attack = true

# ============================================
# BEAM SYSTEM
# ============================================
func _fire_beam(origin: Vector2, direction: Vector2, magic_multiplier: float):
	var beam_visual = _create_beam_visual(origin, direction)
	var final_damage = beam_damage * magic_multiplier

	_damage_enemies_in_beam(origin, direction, final_damage)

	# Screen shake
	DamageNumberManager.shake(0.4)

	await _animate_beam(beam_visual)

func _create_beam_visual(origin: Vector2, direction: Vector2) -> Node2D:
	var container = Node2D.new()
	container.global_position = origin
	container.rotation = direction.angle()
	get_tree().root.add_child(container)

	# Core beam
	var core = ColorRect.new()
	core.color = _get_beam_color()
	core.size = Vector2(beam_range, beam_width * 0.4)
	core.position = Vector2(0, -beam_width * 0.2)
	container.add_child(core)

	# Outer glow
	var glow = ColorRect.new()
	glow.color = _get_beam_glow_color()
	glow.size = Vector2(beam_range, beam_width)
	glow.position = Vector2(0, -beam_width * 0.5)
	glow.z_index = -1
	container.add_child(glow)

	# Edge highlights
	for y_pos in [-beam_width * 0.5, beam_width * 0.5 - 4]:
		var edge = ColorRect.new()
		edge.color = Color(1.0, 1.0, 1.0, 0.8)
		edge.size = Vector2(beam_range, 4)
		edge.position = Vector2(0, y_pos)
		container.add_child(edge)

	# Origin flash
	var flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.size = Vector2(64, 64)
	flash.position = Vector2(-32, -32)
	flash.pivot_offset = Vector2(32, 32)
	container.add_child(flash)

	return container

func _animate_beam(beam_visual: Node2D):
	beam_visual.modulate = Color(1, 1, 1, 0)
	beam_visual.scale = Vector2(1, 0.3)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(beam_visual, "modulate:a", 1.0, 0.05)
	tween.tween_property(beam_visual, "scale:y", 1.2, 0.05)

	await tween.finished

	if not is_instance_valid(self) or not is_instance_valid(beam_visual):
		if is_instance_valid(beam_visual):
			beam_visual.queue_free()
		return

	await get_tree().create_timer(0.15).timeout

	if not is_instance_valid(self) or not is_instance_valid(beam_visual):
		if is_instance_valid(beam_visual):
			beam_visual.queue_free()
		return

	var fade = TweenHelper.new_tween()
	fade.set_parallel(true)
	fade.tween_property(beam_visual, "modulate:a", 0.0, 0.3)
	fade.tween_property(beam_visual, "scale:y", 0.1, 0.3)

	await fade.finished
	if is_instance_valid(beam_visual):
		beam_visual.queue_free()

func _damage_enemies_in_beam(origin: Vector2, direction: Vector2, final_damage: float):
	var enemies = _get_enemies()
	var hit_enemies: Array = []
	var hitbox_tolerance: float = 16.0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Skip converted minions (NecroStaff allies)
		if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
			continue

		var to_enemy = enemy.global_position - origin
		var distance_along = to_enemy.dot(direction)

		if distance_along < 0 or distance_along > beam_range:
			continue

		var perpendicular = to_enemy - direction * distance_along
		if perpendicular.length() <= beam_width * 0.5 + hitbox_tolerance:
			hit_enemies.append(enemy)

	# Trigger hit-stop for skill if enemies hit
	if hit_enemies.size() > 0 and enable_skill_hit_stop and CombatAnimationSystem:
		CombatAnimationSystem.trigger_hit_stop_for_attack("skill")

	var attacker = player_reference if is_instance_valid(player_reference) else null
	for enemy in hit_enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(final_damage, origin, 200.0, 0.1, attacker, damage_type)
			_create_beam_hit_effect(enemy.global_position)

func _create_beam_hit_effect(pos: Vector2):
	var flash = ColorRect.new()
	flash.color = _get_beam_color()
	flash.size = Vector2(32, 32)
	flash.global_position = pos - Vector2(16, 16)
	flash.pivot_offset = Vector2(16, 16)
	get_tree().root.add_child(flash)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2, 2), 0.2)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(flash.queue_free)

# ============================================
# CAST TRAIL SYSTEM
# ============================================
func _create_cast_trail():
	if not enable_cast_trail:
		return

	_trail_points.clear()
	_is_casting = true

	if _active_trail and is_instance_valid(_active_trail):
		_active_trail.queue_free()

	var scene = get_tree().current_scene
	if not scene:
		return

	_active_trail = Line2D.new()
	_active_trail.width = trail_width
	_active_trail.default_color = Color.WHITE
	_active_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_active_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_active_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_active_trail.texture_mode = Line2D.LINE_TEXTURE_STRETCH

	# Width curve - thin at old, thick at new
	var width_curve = Curve.new()
	width_curve.add_point(Vector2(0.0, 0.0))
	width_curve.add_point(Vector2(0.5, 0.5))
	width_curve.add_point(Vector2(1.0, 1.0))
	_active_trail.width_curve = width_curve

	# Apply shader
	_trail_shader_material = ShaderMaterial.new()
	_trail_shader_material.shader = _magic_trail_shader

	var trail_color = _get_trail_color()
	var glow_color = _get_trail_glow_color()

	_trail_shader_material.set_shader_parameter("trail_color", trail_color)
	_trail_shader_material.set_shader_parameter("glow_color", glow_color)
	_trail_shader_material.set_shader_parameter("glow_intensity", _get_trail_glow_intensity())
	_trail_shader_material.set_shader_parameter("pulse_speed", _get_trail_pulse_speed())
	_trail_shader_material.set_shader_parameter("sparkle_amount", _get_trail_sparkle_amount())

	_active_trail.material = _trail_shader_material
	scene.add_child(_active_trail)

func _get_staff_tip_position() -> Vector2:
	if projectile_spawn:
		return projectile_spawn.global_position
	return global_position

func _update_cast_trail():
	if not _active_trail or not is_instance_valid(_active_trail):
		return

	if not _is_casting:
		# Fade out
		if _active_trail.modulate.a > 0:
			_active_trail.modulate.a -= get_process_delta_time() * TRAIL_FADE_SPEED
			if _active_trail.modulate.a <= 0:
				_active_trail.queue_free()
				_active_trail = null
				_trail_points.clear()
		return

	# Add current tip position
	var tip_pos = _get_staff_tip_position()
	_trail_points.append(tip_pos)

	# Limit trail length
	while _trail_points.size() > TRAIL_MAX_POINTS:
		_trail_points.remove_at(0)

	# Update Line2D
	_active_trail.clear_points()
	for point in _trail_points:
		_active_trail.add_point(point)

func _end_cast_trail():
	_is_casting = false

# ============================================
# VIRTUAL TRAIL METHODS - Override in subclasses
# ============================================
func _get_trail_color() -> Color:
	# Default arcane blue
	return Color(0.4, 0.8, 1.0, 0.9)

func _get_trail_glow_color() -> Color:
	return Color(1.0, 1.0, 1.0, 1.0)

func _get_trail_glow_intensity() -> float:
	return 1.5

func _get_trail_pulse_speed() -> float:
	return 4.0

func _get_trail_sparkle_amount() -> float:
	return 0.3

# ============================================
# WALK ANIMATION SYSTEM
# ============================================
func _update_walk_animation(delta: float):
	# Skip if disabled or using skill
	if not enable_walk_animation or is_using_skill or not sprite:
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
	var anim_speed = 5.0 * walk_anim_speed
	_walk_anim_time += delta * anim_speed
	_apply_walk_animation()

func _apply_walk_animation():
	if not sprite:
		return

	# Simple bob and sway - snap to integers for crisp pixels
	var bob_offset = int(sin(_walk_anim_time * 2.0) * walk_bob_amount)
	var sway_rotation = sin(_walk_anim_time) * deg_to_rad(walk_sway_amount)

	# Apply to sprite
	sprite.position = _base_sprite_position + Vector2(0, bob_offset)
	sprite.rotation = _base_sprite_rotation + sway_rotation

func _reset_walk_animation():
	if not sprite:
		return
	# Reset to base state
	sprite.position = _base_sprite_position
	sprite.rotation = _base_sprite_rotation

# ============================================
# PROJECTILE SPAWN CORRECTION
# ============================================
func _correct_projectile_spawn():
	# No correction needed - staff pivot only uses scale.x flip, no rotation
	# This keeps projectile_spawn.global_position calculations correct
	pass


