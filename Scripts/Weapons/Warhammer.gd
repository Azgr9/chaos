# SCRIPT: Warhammer.gd
# ATTACH TO: Warhammer (Node2D) root node in Warhammer.tscn
# LOCATION: res://Scripts/Weapons/Warhammer.gd
# Slow, devastating weapon with Earthquake skill

class_name Warhammer
extends MeleeWeapon

# ============================================
# WARHAMMER-SPECIFIC STATE
# ============================================
var is_earthquaking: bool = false
const EARTHQUAKE_RADIUS: float = 200.0
const EARTHQUAKE_DAMAGE_MULTIPLIER: float = 2.0
const EARTHQUAKE_STUN: float = 0.8

# Shader references
var shockwave_shader: Shader = preload("res://Shaders/Weapons/ImpactShockwave.gdshader")
var crack_shader: Shader = preload("res://Shaders/Weapons/GroundCrack.gdshader")
var energy_shader: Shader = preload("res://Shaders/Weapons/EnergyGlow.gdshader")

# Colors
const HAMMER_GLOW_COLOR: Color = Color(1.0, 0.5, 0.1)  # Orange impact
const HAMMER_EARTH_COLOR: Color = Color(0.5, 0.4, 0.25)  # Earth brown

func _weapon_ready():
	# Warhammer: extremely slow but devastating
	damage = 35.0
	attack_duration = 0.6   # Very slow
	attack_cooldown = 0.8   # Long recovery
	swing_arc = 100.0       # Wide overhead arc
	weapon_length = 70.0    # Shorter, bulky
	weapon_color = Color(0.4, 0.35, 0.3)  # Dark iron

	# Idle appearance - Hammer resting on ground, leaning against player
	idle_rotation = 80.0  # Almost vertical, leaning
	idle_position = Vector2(8, 10)  # Down and to the side (grounded)
	idle_scale = Vector2(0.7, 0.7)

	# Cone Hitbox - Now configured via @export in scene inspector
	# attack_range = 110.0  # Medium range for smash
	# attack_cone_angle = 120.0  # Very wide crushing arc

	# Attack Speed Limits (slowest weapon)
	max_attacks_per_second = 1.5  # Very slow but powerful
	min_cooldown = 0.5  # Cannot swing faster than this

	# Combo settings - slow but powerful
	combo_window = 2.5
	combo_finisher_multiplier = 2.0  # Massive finisher bonus
	combo_hits = 2  # Only 2-hit combo (too heavy for more)

	# Massive knockback
	base_knockback = 700.0
	finisher_knockback = 1200.0
	knockback_stun = 0.3

	# Skill settings
	skill_cooldown = 15.0

func _get_attack_pattern(attack_index: int) -> String:
	# Warhammer: overhead smash -> ground slam
	match attack_index:
		1: return "overhead"
		2: return "slam"
		_: return "overhead"

func _get_hit_color(combo_finisher: bool, dash_attack: bool, crit: bool) -> Color:
	if crit:
		return Color.RED
	elif combo_finisher:
		return Color(1.0, 0.6, 0.0)  # Orange for hammer finisher
	elif dash_attack:
		return Color.CYAN
	return weapon_color

# ============================================
# CUSTOM ATTACK ANIMATIONS
# ============================================
func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	if active_attack_tween:
		active_attack_tween.kill()

	var is_finisher = is_combo_finisher()

	if is_finisher:
		sprite.color = Color(1.0, 0.6, 0.0)  # Orange
	elif is_dash_attack:
		sprite.color = Color.CYAN

	match pattern:
		"overhead":
			_animate_hammer_overhead(duration, is_dash_attack)
		"slam":
			_animate_hammer_slam(duration, is_dash_attack)
		_:
			_animate_hammer_overhead(duration, is_dash_attack)

func _animate_hammer_overhead(duration: float, _is_dash_attack: bool):
	active_attack_tween = TweenHelper.new_tween()

	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	# High windup
	var raise_angle = base_angle - 100
	var smash_angle = base_angle + 40

	pivot.rotation = deg_to_rad(raise_angle)
	pivot.position = Vector2.ZERO
	sprite.scale = Vector2(1.0, 1.0)

	# Long wind up - raise hammer high
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(raise_angle - 30), duration * 0.35)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(is_combo_finisher(), false))

	# Powerful smash down
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(smash_angle), duration * 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Impact shake
	active_attack_tween.tween_callback(func():
		if DamageNumberManager:
			DamageNumberManager.shake(0.2)
	)

	# Slow recovery
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(smash_angle + 5), duration * 0.25)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _animate_hammer_slam(duration: float, _is_dash_attack: bool):
	active_attack_tween = TweenHelper.new_tween()

	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	# Extreme raise for finisher slam
	var raise_angle = base_angle - 140
	var slam_angle = base_angle + 50

	pivot.rotation = deg_to_rad(raise_angle)
	pivot.position = Vector2.ZERO
	sprite.scale = Vector2(1.3, 1.3)  # Bigger for finisher

	# Very long wind up
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(raise_angle - 20), duration * 0.4)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(true, false))

	# Devastating slam
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(slam_angle), duration * 0.2)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Impact - ground crack effect
	active_attack_tween.tween_callback(_create_ground_crack)
	active_attack_tween.tween_interval(duration * 0.15)

	# Recovery
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(slam_angle + 5), duration * 0.15)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _create_ground_crack():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	var impact_pos = player_reference.global_position + current_attack_direction * 70

	# Big screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.5)

	# Shader-based shockwave
	var ring = ColorRect.new()
	ring.size = Vector2(200, 200)
	ring.pivot_offset = Vector2(100, 100)
	ring.global_position = impact_pos - Vector2(100, 100)

	var mat = ShaderMaterial.new()
	mat.shader = shockwave_shader
	mat.set_shader_parameter("wave_color", HAMMER_GLOW_COLOR)
	mat.set_shader_parameter("ring_thickness", 0.15)
	mat.set_shader_parameter("inner_glow", 1.8)
	mat.set_shader_parameter("progress", 0.0)
	ring.material = mat

	scene.add_child(ring)

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.4)
	tween.tween_callback(ring.queue_free)

	# Shader-based ground cracks
	for i in range(8):
		var crack = ColorRect.new()
		crack.size = Vector2(randf_range(70, 110), 8)
		crack.pivot_offset = Vector2(0, 4)
		crack.rotation = (TAU / 8) * i + randf_range(-0.2, 0.2)
		crack.global_position = impact_pos

		var crack_mat = ShaderMaterial.new()
		crack_mat.shader = crack_shader
		crack_mat.set_shader_parameter("crack_color", HAMMER_EARTH_COLOR)
		crack_mat.set_shader_parameter("glow_color", HAMMER_GLOW_COLOR)
		crack_mat.set_shader_parameter("progress", 0.0)
		crack.material = crack_mat

		scene.add_child(crack)

		var crack_tween = TweenHelper.new_tween()
		crack_tween.tween_method(func(p): crack_mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.5)
		crack_tween.tween_callback(crack.queue_free)

	# Debris particles
	for i in range(10):
		var debris = ColorRect.new()
		debris.size = Vector2(randf_range(12, 20), randf_range(12, 20))
		debris.color = Color(0.45, 0.38, 0.28, 1.0)
		debris.pivot_offset = debris.size / 2
		scene.add_child(debris)
		debris.global_position = impact_pos

		var angle = (TAU / 10) * i + randf_range(-0.25, 0.25)
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(70, 140)

		var dtween = TweenHelper.new_tween()
		dtween.set_parallel(true)
		dtween.tween_property(debris, "global_position", impact_pos + dir * dist, 0.35)
		dtween.tween_property(debris, "global_position:y", debris.global_position.y + 60, 0.35).set_delay(0.18)
		dtween.tween_property(debris, "rotation", randf_range(-TAU, TAU), 0.35)
		dtween.tween_property(debris, "modulate:a", 0.0, 0.35)
		dtween.tween_callback(debris.queue_free)

# ============================================
# EARTHQUAKE SKILL - AoE ground pound (stays in place)
# ============================================

## This is an async skill - it uses await and manages its own invulnerability
func _is_async_skill() -> bool:
	return true

func _perform_skill() -> bool:
	if not player_reference or is_earthquaking:
		return false

	is_earthquaking = true
	_execute_earthquake()
	return true

func _execute_earthquake():
	if not is_instance_valid(player_reference):
		is_earthquaking = false
		_end_skill_invulnerability()
		return

	# Visual: hammer glows and raises
	sprite.color = Color(1.0, 0.5, 0.0)
	sprite.scale = Vector2(1.5, 1.5)

	# Raise hammer high animation
	var raise_tween = TweenHelper.new_tween()
	raise_tween.tween_property(pivot, "rotation", deg_to_rad(-120), 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	raise_tween.parallel().tween_property(pivot, "position:y", -30, 0.25)

	await raise_tween.finished

	# Check validity after await
	if not is_instance_valid(self) or not is_instance_valid(player_reference):
		is_earthquaking = false
		_end_skill_invulnerability()
		return

	# Brief pause at top
	await get_tree().create_timer(0.1).timeout

	if not is_instance_valid(self) or not is_instance_valid(player_reference):
		is_earthquaking = false
		_end_skill_invulnerability()
		return

	# Slam down animation
	var slam_tween = TweenHelper.new_tween()
	slam_tween.tween_property(pivot, "rotation", deg_to_rad(45), 0.12)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	slam_tween.parallel().tween_property(pivot, "position:y", 0, 0.12)

	await slam_tween.finished

	# Check validity after await
	if not is_instance_valid(self) or not is_instance_valid(player_reference):
		is_earthquaking = false
		_end_skill_invulnerability()
		return

	# Earthquake impact!
	_earthquake_impact()

	# Reset hammer to idle
	var reset_tween = TweenHelper.new_tween()
	reset_tween.tween_property(sprite, "color", weapon_color, 0.2)
	reset_tween.parallel().tween_property(sprite, "scale", idle_scale, 0.2)
	reset_tween.parallel().tween_property(pivot, "rotation", deg_to_rad(idle_rotation), 0.2)

	await reset_tween.finished

	is_earthquaking = false
	# End invulnerability when skill is complete
	_end_skill_invulnerability()

func _earthquake_impact():
	if not player_reference:
		return

	var impact_pos = player_reference.global_position

	# Massive screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.8)

	# Damage all enemies in radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var distance = enemy.global_position.distance_to(impact_pos)
		if distance < EARTHQUAKE_RADIUS:
			var eq_damage = damage * damage_multiplier * EARTHQUAKE_DAMAGE_MULTIPLIER
			# Damage falls off with distance
			var falloff = 1.0 - (distance / EARTHQUAKE_RADIUS) * 0.5
			eq_damage *= falloff

			if enemy.has_method("take_damage"):
				var attacker = player_reference if is_instance_valid(player_reference) else null
				enemy.take_damage(eq_damage, impact_pos, 800.0, EARTHQUAKE_STUN, attacker)
				dealt_damage.emit(enemy, eq_damage)

	# Visual effects - multiple shockwave rings
	for i in range(3):
		_create_shockwave_ring(impact_pos, i * 0.1)

	# Ground crack particles
	_create_earthquake_debris(impact_pos)

func _create_shockwave_ring(pos: Vector2, delay: float):
	await get_tree().create_timer(delay).timeout

	# Check validity after await
	if not is_instance_valid(self):
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Massive shader-based shockwave for earthquake
	var ring = ColorRect.new()
	ring.size = Vector2(EARTHQUAKE_RADIUS * 2, EARTHQUAKE_RADIUS * 2)
	ring.pivot_offset = Vector2(EARTHQUAKE_RADIUS, EARTHQUAKE_RADIUS)
	ring.global_position = pos - Vector2(EARTHQUAKE_RADIUS, EARTHQUAKE_RADIUS)

	var mat = ShaderMaterial.new()
	mat.shader = shockwave_shader
	mat.set_shader_parameter("wave_color", Color(0.7, 0.5, 0.2, 0.9))
	mat.set_shader_parameter("ring_thickness", 0.1)
	mat.set_shader_parameter("inner_glow", 2.0)
	mat.set_shader_parameter("distortion", 0.03)
	mat.set_shader_parameter("progress", 0.0)
	ring.material = mat

	scene.add_child(ring)

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.5)
	tween.tween_callback(ring.queue_free)

func _create_earthquake_debris(pos: Vector2):
	for i in range(16):
		var debris = ColorRect.new()
		debris.size = Vector2(randf_range(10, 25), randf_range(10, 25))
		debris.color = Color(0.5, 0.4, 0.3, 1.0)
		get_tree().current_scene.add_child(debris)
		debris.global_position = pos

		var angle = (TAU / 16) * i + randf_range(-0.2, 0.2)
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(80, EARTHQUAKE_RADIUS)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(debris, "global_position", pos + dir * dist, 0.5)
		tween.tween_property(debris, "rotation", randf_range(-PI, PI), 0.5)
		tween.tween_property(debris, "modulate:a", 0.0, 0.5)
		tween.tween_callback(debris.queue_free)

func _on_combo_finisher_hit(_target: Node2D):
	# Extra massive shake on finisher
	if DamageNumberManager:
		DamageNumberManager.shake(0.6)

# Block attacks during earthquake
func attack(direction: Vector2, player_damage_multiplier: float = 1.0) -> bool:
	if is_earthquaking:
		return false
	return super.attack(direction, player_damage_multiplier)
