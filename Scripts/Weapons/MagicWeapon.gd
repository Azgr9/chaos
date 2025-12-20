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
@export var projectile_spread: float = 5.0  # Degrees of random spread
@export var multi_shot: int = 1
@export var damage: float = 10.0

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

# ============================================
# NODES - Expected in scene tree
# ============================================
@onready var sprite: ColorRect = $Sprite
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
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	muzzle_flash.modulate.a = 0.0

	# Load default projectile if not set
	if not projectile_scene:
		projectile_scene = preload("res://Scenes/Spells/BasicProjectile.tscn")

	# Get player reference
	await get_tree().process_frame
	player_reference = get_tree().get_first_node_in_group("player")

	_weapon_ready()

func _process(delta):
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
	if not skill_ready:
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

func _fire_projectiles(direction: Vector2):
	for i in range(multi_shot):
		if not projectile_scene:
			continue

		var projectile = projectile_scene.instantiate()
		get_tree().root.add_child(projectile)

		# Calculate spread
		var spread_angle = _calculate_spread_angle(i)
		var final_direction = direction.rotated(spread_angle)

		# Initialize projectile (pass player for thorns reflection)
		projectile.initialize(
			projectile_spawn.global_position,
			final_direction,
			damage_multiplier,
			400.0,  # knockback_power
			0.1,    # hitstun_duration
			player_reference  # attacker for thorns
		)

		# Apply custom projectile visuals
		_customize_projectile(projectile)

		projectile_fired.emit(projectile)

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
	# Muzzle flash
	muzzle_flash.modulate.a = 1.0
	var flash_tween = create_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.1)

	# Staff recoil
	var recoil_tween = create_tween()
	recoil_tween.tween_property(self, "position:x", -12, 0.05)
	recoil_tween.tween_property(self, "position:x", 0, 0.1)

	# Staff glow
	var original_color = sprite.color
	sprite.color = staff_color.lightened(0.3)
	await get_tree().create_timer(0.1).timeout
	sprite.color = original_color

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

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(beam_visual, "modulate:a", 1.0, 0.05)
	tween.tween_property(beam_visual, "scale:y", 1.2, 0.05)

	await tween.finished
	await get_tree().create_timer(0.15).timeout

	var fade = create_tween()
	fade.set_parallel(true)
	fade.tween_property(beam_visual, "modulate:a", 0.0, 0.3)
	fade.tween_property(beam_visual, "scale:y", 0.1, 0.3)

	await fade.finished
	beam_visual.queue_free()

func _damage_enemies_in_beam(origin: Vector2, direction: Vector2, final_damage: float):
	var enemies = _get_enemies()
	var hit_enemies: Array = []
	var hitbox_tolerance: float = 16.0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var to_enemy = enemy.global_position - origin
		var distance_along = to_enemy.dot(direction)

		if distance_along < 0 or distance_along > beam_range:
			continue

		var perpendicular = to_enemy - direction * distance_along
		if perpendicular.length() <= beam_width * 0.5 + hitbox_tolerance:
			hit_enemies.append(enemy)

	var attacker = player_reference if is_instance_valid(player_reference) else null
	for enemy in hit_enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(final_damage, origin, 200.0, 0.1, attacker)
			_create_beam_hit_effect(enemy.global_position)

func _create_beam_hit_effect(pos: Vector2):
	var flash = ColorRect.new()
	flash.color = _get_beam_color()
	flash.size = Vector2(32, 32)
	flash.global_position = pos - Vector2(16, 16)
	flash.pivot_offset = Vector2(16, 16)
	get_tree().root.add_child(flash)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2, 2), 0.2)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(flash.queue_free)
