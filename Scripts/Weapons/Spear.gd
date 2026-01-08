# SCRIPT: Spear.gd
# ATTACH TO: Spear (Node2D) root node in Spear.tscn
# LOCATION: res://Scripts/Weapons/Spear.gd
# Dragon Spear - Long range thrust attacks with pierce

class_name Spear
extends MeleeWeapon

# ============================================
# SPEAR-SPECIFIC SETTINGS
# ============================================

# Pierce settings
const MAX_PIERCE_TARGETS: int = 3
const PIERCE_DAMAGE_FALLOFF: float = 0.15  # 15% less damage per pierce

# Thrust settings - Increased range for longer reach
const THRUST_RANGE: float = 220.0  # Extended forward thrust
const CHARGE_THRUST_RANGE: float = 380.0  # Extended charge thrust
const CHARGE_THRUST_DAMAGE_MULT: float = 2.0

# Visual colors - Bronze/gold warrior theme
const SPEAR_TIP_COLOR: Color = Color(0.85, 0.7, 0.3)  # Bronze tip
const SPEAR_SHAFT_COLOR: Color = Color(0.45, 0.3, 0.2)  # Dark wood shaft
const SPEAR_ACCENT_COLOR: Color = Color(1.0, 0.85, 0.4)  # Gold accent
const SPEAR_THRUST_COLOR: Color = Color(1.0, 0.9, 0.5, 0.8)  # Bright thrust trail

# Shader references
var thrust_shader: Shader = preload("res://Shaders/Weapons/ThrustTrail.gdshader")
var spark_shader: Shader = preload("res://Shaders/Weapons/SparkBurst.gdshader")
var shockwave_shader: Shader = preload("res://Shaders/Weapons/ImpactShockwave.gdshader")
var energy_shader: Shader = preload("res://Shaders/Weapons/EnergyGlow.gdshader")

# State
var pierced_enemies: Array = []
var is_charging: bool = false
var charge_time: float = 0.0
const MAX_CHARGE_TIME: float = 1.0

func _weapon_ready():
	# Spear - long range, thrust-focused, piercing
	damage = 15.0
	attack_duration = 0.28  # Quick thrusts
	attack_cooldown = 0.35
	swing_arc = 30.0  # Narrow - thrust weapon
	weapon_length = 140.0  # VERY long reach
	weapon_color = SPEAR_TIP_COLOR
	skill_cooldown = 8.0

	# Cone Hitbox - Now configured via @export in scene inspector
	# attack_range = 220.0  # Longest range in game
	# attack_cone_angle = 45.0  # Narrow but usable thrust cone

	# Attack Speed Limits
	max_attacks_per_second = 3.5
	min_cooldown = 0.2

	# Idle - Spear held upright like a guard
	idle_rotation = -10.0  # Nearly vertical, slightly forward
	idle_position = Vector2(5, -8)  # Slightly forward and up
	idle_scale = Vector2(0.55, 0.55)

	# Moderate knockback (piercing reduces knockback)
	base_knockback = 250.0
	finisher_knockback = 450.0

	# Combo - rapid thrusts
	combo_finisher_multiplier = 1.5
	combo_window = 1.5
	combo_hits = 4  # 4-hit combo for spear

	# Walk animation - long weapon = more tip movement, medium speed
	walk_bob_amount = 9.0  # Medium bob
	walk_sway_amount = 14.0  # More sway (long weapon tip moves more)
	walk_anim_speed = 0.9  # Slightly slow

	# Apply idle state after setting custom values
	_setup_idle_state()

func _get_attack_pattern(attack_index: int) -> String:
	# Spear: thrust -> thrust -> thrust -> impale
	match attack_index:
		1: return "thrust"
		2: return "thrust_high"
		3: return "thrust_low"
		4: return "impale"
		_: return "thrust"

func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	if active_attack_tween:
		active_attack_tween.kill()

	# Reset pierce tracking
	pierced_enemies.clear()

	var is_finisher = is_combo_finisher()

	if sprite:
		if is_finisher:
			sprite.color = SPEAR_ACCENT_COLOR
		elif is_dash_attack:
			sprite.color = Color.CYAN

	match pattern:
		"thrust":
			_animate_thrust(duration, is_dash_attack, 0)
		"thrust_high":
			_animate_thrust(duration, is_dash_attack, -15)
		"thrust_low":
			_animate_thrust(duration, is_dash_attack, 15)
		"impale":
			_animate_impale(duration, is_dash_attack)
		_:
			_animate_thrust(duration, is_dash_attack, 0)

func _animate_thrust(duration: float, _is_dash_attack: bool, angle_offset: float):
	active_attack_tween = TweenHelper.new_tween()

	# Add 90 degrees because sprite points UP, but we want it to point in attack direction
	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0
	var thrust_angle = base_angle + angle_offset

	# Start pulled back
	if pivot:
		pivot.rotation = deg_to_rad(thrust_angle)
		pivot.position = current_attack_direction * -30  # Pulled back
	if sprite:
		sprite.scale = Vector2(1.0, 1.0)

	# Quick wind-up
	active_attack_tween.tween_property(pivot, "position", current_attack_direction * -40, duration * 0.15)

	# Spear glint effect
	active_attack_tween.tween_callback(_create_spear_glint)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(is_combo_finisher(), false))

	# THRUST forward - main attack
	active_attack_tween.tween_callback(_start_thrust_trail)
	active_attack_tween.tween_property(pivot, "position", current_attack_direction * THRUST_RANGE, duration * 0.35)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# Impact spark
	active_attack_tween.tween_callback(_create_thrust_impact)

	# Brief hold at extension
	active_attack_tween.tween_interval(duration * 0.1)

	# Retract
	active_attack_tween.tween_property(pivot, "position", Vector2.ZERO, duration * 0.25)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _animate_impale(duration: float, _is_dash_attack: bool):
	# Finisher - Powerful piercing thrust
	active_attack_tween = TweenHelper.new_tween()

	# Add 90 degrees because sprite points UP, but we want it to point in attack direction
	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	if pivot:
		pivot.rotation = deg_to_rad(base_angle)
		pivot.position = current_attack_direction * -50  # Far back
	if sprite:
		sprite.scale = Vector2(1.3, 1.3)
		sprite.color = SPEAR_ACCENT_COLOR

	# Charge effect
	_create_charge_effect()

	# Long wind-up
	active_attack_tween.tween_property(pivot, "position", current_attack_direction * -60, duration * 0.2)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(true, false))

	# Intense thrust trail
	active_attack_tween.tween_callback(_start_impale_trail)

	# MASSIVE thrust - pierces everything
	active_attack_tween.tween_property(pivot, "position", current_attack_direction * CHARGE_THRUST_RANGE, duration * 0.3)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# Shockwave at max extension
	active_attack_tween.tween_callback(_create_impale_shockwave)

	# Brief dramatic pause
	active_attack_tween.tween_interval(duration * 0.15)

	# Slow retract
	active_attack_tween.tween_property(pivot, "position", Vector2.ZERO, duration * 0.2)
	active_attack_tween.tween_property(sprite, "color", weapon_color, duration * 0.15)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

# ============================================
# PIERCE SYSTEM - Override _calculate_damage for pierce tracking
# ============================================
func _calculate_damage(target: Node2D) -> float:
	# Track pierced enemies for damage falloff
	if target not in pierced_enemies:
		pierced_enemies.append(target)

	var base_damage = super._calculate_damage(target)

	# Apply pierce damage falloff based on pierce order
	var pierce_index = pierced_enemies.find(target)
	if pierce_index > 0:
		var falloff = 1.0 - (pierce_index * PIERCE_DAMAGE_FALLOFF)
		falloff = maxf(falloff, 0.4)  # Minimum 40% damage
		base_damage *= falloff

	# Pierce visual (deferred to avoid issues during damage calculation)
	call_deferred("_create_pierce_effect", target.global_position)

	return base_damage

func _create_pierce_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Blood/impact splatter in thrust direction
	for i in range(4):
		var blood = ColorRect.new()
		blood.size = Vector2(6, 12)
		blood.color = Color(0.8, 0.2, 0.2, 0.9)
		blood.pivot_offset = Vector2(3, 6)
		scene.add_child(blood)
		blood.global_position = pos

		var angle = current_attack_direction.angle() + randf_range(-0.4, 0.4)
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(30, 60)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(blood, "global_position", pos + dir * dist, 0.2)
		tween.tween_property(blood, "modulate:a", 0.0, 0.25)
		tween.tween_property(blood, "scale", Vector2(0.3, 0.3), 0.25)
		tween.tween_callback(blood.queue_free)

# ============================================
# VISUAL EFFECTS
# ============================================
func _create_spear_glint():
	var scene = get_tree().current_scene
	if not scene:
		return

	# Quick shine on spear tip
	var glint = ColorRect.new()
	glint.size = Vector2(8, 8)
	glint.color = Color.WHITE
	glint.pivot_offset = Vector2(4, 4)
	scene.add_child(glint)
	glint.global_position = global_position + current_attack_direction * weapon_length

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(glint, "scale", Vector2(2, 2), 0.1)
	tween.tween_property(glint, "modulate:a", 0.0, 0.1)
	tween.tween_callback(glint.queue_free)

func _start_thrust_trail():
	_create_thrust_trail(4)

func _start_impale_trail():
	_create_thrust_trail(8)

func _create_thrust_trail(count: int):
	for i in range(count):
		_spawn_thrust_trail_segment(i * 0.02)

func _spawn_thrust_trail_segment(delay: float):
	await get_tree().create_timer(delay).timeout

	if not is_instance_valid(self):
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Shader-based thrust trail
	var trail = ColorRect.new()
	trail.size = Vector2(weapon_length * 1.0, 16)
	trail.pivot_offset = Vector2(0, 8)
	scene.add_child(trail)
	trail.global_position = global_position
	trail.rotation = current_attack_direction.angle()

	var mat = ShaderMaterial.new()
	mat.shader = thrust_shader
	mat.set_shader_parameter("thrust_color", SPEAR_THRUST_COLOR)
	mat.set_shader_parameter("tip_color", SPEAR_TIP_COLOR)
	mat.set_shader_parameter("glow_intensity", 2.0)
	mat.set_shader_parameter("sharpness", 3.0)
	mat.set_shader_parameter("progress", 0.0)
	trail.material = mat

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.15)
	tween.tween_callback(trail.queue_free)

func _create_thrust_impact():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	var impact_pos = player_reference.global_position + current_attack_direction * THRUST_RANGE

	# Shader-based spark burst
	var spark_burst = ColorRect.new()
	spark_burst.size = Vector2(60, 60)
	spark_burst.pivot_offset = Vector2(30, 30)
	spark_burst.global_position = impact_pos - Vector2(30, 30)

	var mat = ShaderMaterial.new()
	mat.shader = spark_shader
	mat.set_shader_parameter("spark_color", SPEAR_ACCENT_COLOR)
	mat.set_shader_parameter("hot_color", Color(1.0, 1.0, 0.9))
	mat.set_shader_parameter("spark_count", 6.0)
	mat.set_shader_parameter("rotation_speed", 4.0)
	mat.set_shader_parameter("progress", 0.0)
	spark_burst.material = mat

	scene.add_child(spark_burst)

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.18)
	tween.tween_callback(spark_burst.queue_free)

func _create_charge_effect():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Shader-based energy glow at spear tip
	var glow = ColorRect.new()
	glow.size = Vector2(60, 60)
	glow.pivot_offset = Vector2(30, 30)
	var tip_pos = global_position + current_attack_direction * weapon_length
	glow.global_position = tip_pos - Vector2(30, 30)

	var mat = ShaderMaterial.new()
	mat.shader = energy_shader
	mat.set_shader_parameter("energy_color", SPEAR_ACCENT_COLOR)
	mat.set_shader_parameter("core_color", Color(1.0, 1.0, 0.9))
	mat.set_shader_parameter("pulse_speed", 12.0)
	mat.set_shader_parameter("intensity", 2.0)
	mat.set_shader_parameter("progress", 0.0)
	glow.material = mat

	scene.add_child(glow)

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 0.8, 0.2)
	tween.tween_callback(glow.queue_free)

	# Energy particles gathering
	for i in range(6):
		var particle = ColorRect.new()
		particle.size = Vector2(12, 12)
		particle.color = SPEAR_ACCENT_COLOR
		particle.pivot_offset = Vector2(6, 6)
		scene.add_child(particle)

		var angle = (TAU / 6) * i
		var start_pos = global_position + Vector2.from_angle(angle) * 50
		particle.global_position = start_pos

		var p_tween = TweenHelper.new_tween()
		p_tween.set_parallel(true)
		p_tween.tween_property(particle, "global_position", tip_pos, 0.2)
		p_tween.tween_property(particle, "scale", Vector2(0.2, 0.2), 0.2)
		p_tween.tween_callback(particle.queue_free)

func _create_impale_shockwave():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	var impact_pos = player_reference.global_position + current_attack_direction * CHARGE_THRUST_RANGE

	# Shader-based shockwave ring
	var wave = ColorRect.new()
	wave.size = Vector2(200, 200)
	wave.pivot_offset = Vector2(100, 100)
	wave.global_position = impact_pos - Vector2(100, 100)

	var wave_mat = ShaderMaterial.new()
	wave_mat.shader = shockwave_shader
	wave_mat.set_shader_parameter("wave_color", Color(SPEAR_ACCENT_COLOR.r, SPEAR_ACCENT_COLOR.g, SPEAR_ACCENT_COLOR.b, 0.8))
	wave_mat.set_shader_parameter("ring_thickness", 0.12)
	wave_mat.set_shader_parameter("inner_glow", 1.8)
	wave_mat.set_shader_parameter("progress", 0.0)
	wave.material = wave_mat

	scene.add_child(wave)

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): wave_mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.3)
	tween.tween_callback(wave.queue_free)

	# Shader-based spark burst
	var spark_burst = ColorRect.new()
	spark_burst.size = Vector2(120, 120)
	spark_burst.pivot_offset = Vector2(60, 60)
	spark_burst.global_position = impact_pos - Vector2(60, 60)

	var spark_mat = ShaderMaterial.new()
	spark_mat.shader = spark_shader
	spark_mat.set_shader_parameter("spark_color", SPEAR_ACCENT_COLOR)
	spark_mat.set_shader_parameter("hot_color", Color(1.0, 1.0, 0.95))
	spark_mat.set_shader_parameter("spark_count", 8.0)
	spark_mat.set_shader_parameter("rotation_speed", 6.0)
	spark_mat.set_shader_parameter("progress", 0.0)
	spark_burst.material = spark_mat

	scene.add_child(spark_burst)

	var spark_tween = TweenHelper.new_tween()
	spark_tween.tween_method(func(p): spark_mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.25)
	spark_tween.tween_callback(spark_burst.queue_free)

	# Screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.35)

# ============================================
# SKILL - VALKYRIE THROW (Throw spear, explosion at impact, teleport to location!)
# ============================================
const THROW_RANGE: float = 500.0  # Maximum throw distance
const THROW_SPEED: float = 2000.0  # Very fast projectile (increased)
const EXPLOSION_RADIUS: float = 150.0  # Explosion damage radius
const THROW_DAMAGE_MULT: float = 3.0  # Damage multiplier

var is_throwing: bool = false
var thrown_spear_target: Vector2 = Vector2.ZERO

func _perform_skill() -> bool:
	if not player_reference or is_throwing:
		return false

	is_throwing = true
	_execute_valkyrie_throw()
	return true

func _is_async_skill() -> bool:
	return true

func _execute_valkyrie_throw():
	var player = player_reference
	if not is_instance_valid(player):
		is_throwing = false
		_end_skill_invulnerability()
		return

	var self_ref = weakref(self)
	var player_ref = weakref(player)

	# Get target position (mouse position, clamped to max range)
	var mouse_pos = player.get_global_mouse_position()
	var direction = (mouse_pos - player.global_position).normalized()
	var distance = min(player.global_position.distance_to(mouse_pos), THROW_RANGE)
	var target_pos = player.global_position + direction * distance
	thrown_spear_target = target_pos

	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	var scene = get_tree().current_scene
	if not scene:
		is_throwing = false
		_end_skill_invulnerability()
		return

	# Wind-up animation - pull spear back
	if sprite:
		sprite.color = SPEAR_ACCENT_COLOR

	var windup_tween = TweenHelper.new_tween()
	windup_tween.tween_property(pivot, "rotation", direction.angle() + PI/2 - 0.5, 0.08)
	windup_tween.parallel().tween_property(pivot, "position", -direction * 30, 0.08)

	# Energy gathering effect
	_create_throw_buildup(player.global_position, direction, scene)

	await get_tree().create_timer(0.1).timeout

	if not self_ref.get_ref() or not player_ref.get_ref():
		is_throwing = false
		return

	# Hide weapon (it's being thrown)
	visible = false

	# Screen shake on throw
	DamageNumberManager.shake(0.3)

	# Create and throw the spear projectile
	var start_pos = player.global_position
	var spear_projectile = _create_thrown_spear(start_pos, direction, scene)

	# Animate spear flying
	var travel_time = distance / THROW_SPEED
	var hit_enemies: Array = []

	# Start damage checking during flight
	_spear_flight_damage(spear_projectile, direction, travel_time, hit_enemies, player_ref)

	# Tween spear to target
	var throw_tween = TweenHelper.new_tween()
	throw_tween.tween_property(spear_projectile, "global_position", target_pos, travel_time)\
		.set_trans(Tween.TRANS_LINEAR)

	await throw_tween.finished

	if not self_ref.get_ref() or not player_ref.get_ref():
		if is_instance_valid(spear_projectile):
			spear_projectile.queue_free()
		is_throwing = false
		return

	# EXPLOSION at impact!
	_create_impact_explosion_effect(target_pos, scene, player_ref)

	# Clean up spear projectile
	if is_instance_valid(spear_projectile):
		spear_projectile.queue_free()

	# Brief pause before teleport
	await get_tree().create_timer(0.05).timeout

	if not self_ref.get_ref() or not player_ref.get_ref():
		is_throwing = false
		return

	# TELEPORT player to spear location!
	_teleport_player(player, target_pos, scene)

	# Wait for teleport effect
	await get_tree().create_timer(0.08).timeout

	# Reset weapon
	if self_ref.get_ref():
		is_throwing = false
		visible = true
		if sprite:
			sprite.color = weapon_color

		pivot.rotation = 0
		pivot.position = Vector2.ZERO
		_setup_idle_state()

		_end_skill_invulnerability()

func _create_throw_buildup(pos: Vector2, direction: Vector2, scene: Node):
	# Energy particles gathering at spear tip (faster)
	for i in range(6):
		var particle = ColorRect.new()
		particle.size = Vector2(14, 14)
		particle.pivot_offset = Vector2(7, 7)
		particle.color = SPEAR_ACCENT_COLOR
		scene.add_child(particle)

		var angle = (TAU / 6) * i
		var start = pos + Vector2.from_angle(angle) * 40
		particle.position = start

		var target = pos + direction * 30
		var tween = TweenHelper.new_tween()
		tween.tween_property(particle, "position", target, 0.08)
		tween.parallel().tween_property(particle, "scale", Vector2(0.2, 0.2), 0.08)
		tween.tween_callback(particle.queue_free)

	# Glowing aura around player (faster)
	var aura = ColorRect.new()
	aura.size = Vector2(80, 80)
	aura.pivot_offset = Vector2(40, 40)
	aura.position = pos - Vector2(40, 40)
	aura.color = Color(SPEAR_ACCENT_COLOR.r, SPEAR_ACCENT_COLOR.g, SPEAR_ACCENT_COLOR.b, 0.5)
	scene.add_child(aura)

	var a_tween = TweenHelper.new_tween()
	a_tween.tween_property(aura, "scale", Vector2(1.5, 1.5), 0.08)
	a_tween.parallel().tween_property(aura, "modulate:a", 0.0, 0.1)
	a_tween.tween_callback(aura.queue_free)

func _create_thrown_spear(start_pos: Vector2, direction: Vector2, scene: Node) -> Node2D:
	var spear = Node2D.new()
	spear.global_position = start_pos
	spear.rotation = direction.angle() + PI/2  # Point in direction of travel
	scene.add_child(spear)

	# Spear shaft
	var shaft = ColorRect.new()
	shaft.size = Vector2(12, weapon_length * 1.2)
	shaft.pivot_offset = Vector2(6, weapon_length * 0.6)
	shaft.position = Vector2(-6, -weapon_length * 0.6)
	shaft.color = SPEAR_SHAFT_COLOR
	spear.add_child(shaft)

	# Spear tip (glowing)
	var tip = ColorRect.new()
	tip.size = Vector2(20, 40)
	tip.pivot_offset = Vector2(10, 40)
	tip.position = Vector2(-10, -weapon_length * 0.6 - 20)
	tip.color = SPEAR_ACCENT_COLOR
	spear.add_child(tip)

	# Energy trail effect
	_create_spear_flight_trail(spear, scene)

	return spear

func _create_spear_flight_trail(spear: Node2D, scene: Node):
	# Spawn trail particles during flight
	for i in range(15):
		_spawn_flight_trail_particle(spear, i * 0.02, scene)

func _spawn_flight_trail_particle(spear: Node2D, delay: float, scene: Node):
	await get_tree().create_timer(delay).timeout

	if not is_instance_valid(spear):
		return

	var trail = ColorRect.new()
	trail.size = Vector2(8, 25)
	trail.pivot_offset = Vector2(4, 12.5)
	trail.global_position = spear.global_position
	trail.rotation = spear.rotation
	trail.color = Color(SPEAR_THRUST_COLOR.r, SPEAR_THRUST_COLOR.g, SPEAR_THRUST_COLOR.b, 0.7)
	scene.add_child(trail)

	var tween = TweenHelper.new_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.15)
	tween.parallel().tween_property(trail, "scale", Vector2(0.3, 0.3), 0.15)
	tween.tween_callback(trail.queue_free)

func _spear_flight_damage(spear: Node2D, _direction: Vector2, total_time: float, hit_enemies: Array, player_ref: WeakRef):
	var checks = int(total_time * 40)
	var check_interval = total_time / max(checks, 1)

	for i in range(checks):
		await get_tree().create_timer(check_interval).timeout

		if not is_instance_valid(spear):
			return

		var spear_pos = spear.global_position
		var enemies = get_tree().get_nodes_in_group("enemies")
		var player = player_ref.get_ref()

		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if enemy in hit_enemies:
				continue
			if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
				continue

			var dist = enemy.global_position.distance_to(spear_pos)
			if dist < 40.0:  # Hit radius during flight
				hit_enemies.append(enemy)

				var throw_damage = damage * THROW_DAMAGE_MULT * damage_multiplier
				if enemy.has_method("take_damage") and player:
					enemy.take_damage(throw_damage, spear_pos, 300.0, 0.15, player)
					dealt_damage.emit(enemy, throw_damage)

				_create_pierce_hit_effect(enemy.global_position)
				DamageNumberManager.shake(0.1)

func _create_pierce_hit_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	var flash = ColorRect.new()
	flash.size = Vector2(30, 30)
	flash.pivot_offset = Vector2(15, 15)
	flash.global_position = pos - Vector2(15, 15)
	flash.color = SPEAR_ACCENT_COLOR
	scene.add_child(flash)

	var tween = TweenHelper.new_tween()
	tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.1)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.12)
	tween.tween_callback(flash.queue_free)

func _create_impact_explosion_effect(pos: Vector2, scene: Node, player_ref: WeakRef):
	# Big golden explosion
	var explosion = ColorRect.new()
	explosion.size = Vector2(120, 120)
	explosion.pivot_offset = Vector2(60, 60)
	explosion.position = pos - Vector2(60, 60)
	explosion.color = SPEAR_ACCENT_COLOR
	scene.add_child(explosion)

	var exp_tween = TweenHelper.new_tween()
	exp_tween.tween_property(explosion, "scale", Vector2(3.5, 3.5), 0.2)
	exp_tween.parallel().tween_property(explosion, "modulate:a", 0.0, 0.25)
	exp_tween.tween_callback(explosion.queue_free)

	# Shockwave ring
	var ring = ColorRect.new()
	ring.size = Vector2(100, 100)
	ring.pivot_offset = Vector2(50, 50)
	ring.position = pos - Vector2(50, 50)
	ring.color = Color(SPEAR_THRUST_COLOR.r, SPEAR_THRUST_COLOR.g, SPEAR_THRUST_COLOR.b, 0.6)
	scene.add_child(ring)

	var ring_tween = TweenHelper.new_tween()
	ring_tween.tween_property(ring, "scale", Vector2(5.0, 5.0), 0.3)
	ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
	ring_tween.tween_callback(ring.queue_free)

	# Energy sparks radiating out
	for i in range(12):
		var spark = ColorRect.new()
		spark.size = Vector2(18, 6)
		spark.pivot_offset = Vector2(9, 3)
		spark.position = pos
		spark.rotation = (TAU / 12) * i + randf_range(-0.2, 0.2)
		spark.color = SPEAR_ACCENT_COLOR
		scene.add_child(spark)

		var dir = Vector2.from_angle(spark.rotation)
		var s_tween = TweenHelper.new_tween()
		s_tween.tween_property(spark, "position", pos + dir * randf_range(100, 180), 0.25)
		s_tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.3)
		s_tween.tween_callback(spark.queue_free)

	# Screen shake
	DamageNumberManager.shake(0.5)

	# Deal explosion damage to nearby enemies
	var player = player_ref.get_ref()
	if player:
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
				continue

			var dist = enemy.global_position.distance_to(pos)
			if dist < EXPLOSION_RADIUS:
				var explosion_damage = damage * THROW_DAMAGE_MULT * 1.5 * damage_multiplier
				# Damage falloff based on distance
				var falloff = 1.0 - (dist / EXPLOSION_RADIUS) * 0.5
				explosion_damage *= falloff

				if enemy.has_method("take_damage"):
					enemy.take_damage(explosion_damage, pos, 450.0, 0.2, player)
					dealt_damage.emit(enemy, explosion_damage)

				_create_enemy_hit_flash(enemy.global_position, scene)

func _create_enemy_hit_flash(pos: Vector2, scene: Node):
	var flash = ColorRect.new()
	flash.size = Vector2(40, 40)
	flash.pivot_offset = Vector2(20, 20)
	flash.global_position = pos - Vector2(20, 20)
	flash.color = Color.WHITE
	scene.add_child(flash)

	var tween = TweenHelper.new_tween()
	tween.tween_property(flash, "scale", Vector2(1.8, 1.8), 0.08)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.tween_callback(flash.queue_free)

func _teleport_player(player: Node2D, target_pos: Vector2, scene: Node):
	if not is_instance_valid(player):
		return

	var old_pos = player.global_position

	# Disappear effect at old position
	_create_teleport_vanish_effect(old_pos, scene)

	# Teleport player
	player.global_position = target_pos

	# Appear effect at new position
	_create_teleport_appear_effect(target_pos, scene)

	# Screen shake
	DamageNumberManager.shake(0.25)

func _create_teleport_vanish_effect(pos: Vector2, scene: Node):
	# Particles dispersing from old position
	for i in range(10):
		var particle = ColorRect.new()
		particle.size = Vector2(12, 12)
		particle.pivot_offset = Vector2(6, 6)
		particle.global_position = pos + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		particle.color = SPEAR_ACCENT_COLOR
		scene.add_child(particle)

		var angle = randf() * TAU
		var dir = Vector2.from_angle(angle)
		var tween = TweenHelper.new_tween()
		tween.tween_property(particle, "global_position", particle.global_position + dir * 50, 0.2)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.25)
		tween.parallel().tween_property(particle, "scale", Vector2(0.2, 0.2), 0.25)
		tween.tween_callback(particle.queue_free)

	# Flash at old position
	var flash = ColorRect.new()
	flash.size = Vector2(60, 60)
	flash.pivot_offset = Vector2(30, 30)
	flash.position = pos - Vector2(30, 30)
	flash.color = Color.WHITE
	scene.add_child(flash)

	var f_tween = TweenHelper.new_tween()
	f_tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.1)
	f_tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.12)
	f_tween.tween_callback(flash.queue_free)

func _create_teleport_appear_effect(pos: Vector2, scene: Node):
	# Particles converging to new position
	for i in range(10):
		var particle = ColorRect.new()
		particle.size = Vector2(12, 12)
		particle.pivot_offset = Vector2(6, 6)
		var angle = (TAU / 10) * i
		particle.global_position = pos + Vector2.from_angle(angle) * 60
		particle.color = SPEAR_ACCENT_COLOR
		scene.add_child(particle)

		var tween = TweenHelper.new_tween()
		tween.tween_property(particle, "global_position", pos, 0.15)
		tween.parallel().tween_property(particle, "scale", Vector2(0.3, 0.3), 0.15)
		tween.tween_callback(particle.queue_free)

	# Bright flash at new position
	var flash = ColorRect.new()
	flash.size = Vector2(80, 80)
	flash.pivot_offset = Vector2(40, 40)
	flash.position = pos - Vector2(40, 40)
	flash.color = SPEAR_ACCENT_COLOR
	scene.add_child(flash)

	var f_tween = TweenHelper.new_tween()
	f_tween.tween_property(flash, "scale", Vector2(0.2, 0.2), 0.0)
	f_tween.tween_property(flash, "scale", Vector2(2.5, 2.5), 0.15)
	f_tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.18)
	f_tween.tween_callback(flash.queue_free)

	# Ground impact ring
	var ring = ColorRect.new()
	ring.size = Vector2(50, 50)
	ring.pivot_offset = Vector2(25, 25)
	ring.position = pos - Vector2(25, 25)
	ring.color = Color(SPEAR_THRUST_COLOR.r, SPEAR_THRUST_COLOR.g, SPEAR_THRUST_COLOR.b, 0.7)
	scene.add_child(ring)

	var r_tween = TweenHelper.new_tween()
	r_tween.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.2)
	r_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.25)
	r_tween.tween_callback(ring.queue_free)

func _on_combo_finisher_hit(_target: Node2D):
	if DamageNumberManager:
		DamageNumberManager.shake(0.25)

func _get_hit_color(combo_finisher: bool, dash_attack: bool, crit: bool) -> Color:
	if crit:
		return Color.GOLD
	elif combo_finisher:
		return SPEAR_ACCENT_COLOR
	elif dash_attack:
		return Color.CYAN
	return SPEAR_TIP_COLOR
