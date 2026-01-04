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

# Thrust settings
const THRUST_RANGE: float = 150.0
const CHARGE_THRUST_RANGE: float = 280.0
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
# SKILL - JAVELIN THROW (Throw spear, pierces, returns)
# ============================================
const JAVELIN_RANGE: float = 500.0
const JAVELIN_SPEED: float = 1200.0
const JAVELIN_RETURN_SPEED: float = 800.0
const JAVELIN_DAMAGE_MULT: float = 2.5
const JAVELIN_RETURN_DAMAGE_MULT: float = 1.5

var is_javelin_thrown: bool = false
var javelin_visual: Node2D = null
var javelin_hit_enemies: Array = []

func _perform_skill() -> bool:
	if not player_reference or is_javelin_thrown:
		return false

	is_javelin_thrown = true
	_execute_javelin_throw()
	return true

func _is_async_skill() -> bool:
	return true

func _execute_javelin_throw():
	var player = player_reference
	if not is_instance_valid(player):
		is_javelin_thrown = false
		_end_skill_invulnerability()
		return

	var direction = (player.get_global_mouse_position() - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	# Hide weapon during throw
	visible = false

	# Create thrown javelin visual
	_create_javelin_projectile(player.global_position, direction)

	# Launch effect
	_create_throw_effect(player.global_position, direction)

	if DamageNumberManager:
		DamageNumberManager.shake(0.2)

func _create_javelin_projectile(start_pos: Vector2, direction: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		is_javelin_thrown = false
		visible = true
		_end_skill_invulnerability()
		return

	javelin_hit_enemies.clear()

	# Create javelin visual
	javelin_visual = Node2D.new()
	javelin_visual.global_position = start_pos
	javelin_visual.rotation = direction.angle()
	scene.add_child(javelin_visual)

	# Spear shaft
	var shaft = ColorRect.new()
	shaft.size = Vector2(120, 8)
	shaft.color = SPEAR_SHAFT_COLOR
	shaft.position = Vector2(-60, -4)
	javelin_visual.add_child(shaft)

	# Spear tip
	var tip = ColorRect.new()
	tip.size = Vector2(20, 14)
	tip.color = SPEAR_TIP_COLOR
	tip.position = Vector2(60, -7)
	javelin_visual.add_child(tip)

	# Glowing trail
	var glow = ColorRect.new()
	glow.size = Vector2(80, 16)
	glow.color = Color(SPEAR_ACCENT_COLOR.r, SPEAR_ACCENT_COLOR.g, SPEAR_ACCENT_COLOR.b, 0.4)
	glow.position = Vector2(-80, -8)
	glow.z_index = -1
	javelin_visual.add_child(glow)

	# Fly forward
	var target_pos = start_pos + direction * JAVELIN_RANGE
	var fly_time = JAVELIN_RANGE / JAVELIN_SPEED

	# Damage during forward flight
	_javelin_damage_loop(direction, fly_time, true)

	# Forward flight tween
	var tween = TweenHelper.new_tween()
	tween.tween_property(javelin_visual, "global_position", target_pos, fly_time)\
		.set_trans(Tween.TRANS_LINEAR)

	# Trail during flight
	_create_javelin_trail(fly_time)

	await tween.finished

	if not is_instance_valid(self) or not is_instance_valid(javelin_visual):
		_cleanup_javelin()
		return

	# Brief pause at max range
	_create_impact_flash(javelin_visual.global_position)
	await get_tree().create_timer(0.1).timeout

	if not is_instance_valid(self) or not is_instance_valid(javelin_visual) or not is_instance_valid(player_reference):
		_cleanup_javelin()
		return

	# Return to player
	var return_pos = player_reference.global_position
	var return_direction = (return_pos - javelin_visual.global_position).normalized()
	javelin_visual.rotation = return_direction.angle()

	var return_distance = javelin_visual.global_position.distance_to(return_pos)
	var return_time = return_distance / JAVELIN_RETURN_SPEED

	# Clear hit enemies so we can hit them again on return
	javelin_hit_enemies.clear()

	# Damage during return flight
	_javelin_damage_loop(return_direction, return_time, false)

	# Return trail
	_create_javelin_trail(return_time)

	var return_tween = TweenHelper.new_tween()
	return_tween.tween_method(_update_javelin_return, 0.0, 1.0, return_time)

	await return_tween.finished

	_cleanup_javelin()

func _update_javelin_return(_progress: float):
	if not is_instance_valid(javelin_visual) or not is_instance_valid(player_reference):
		return

	var target = player_reference.global_position
	var current = javelin_visual.global_position
	var new_direction = (target - current).normalized()
	javelin_visual.rotation = new_direction.angle()

	# Move toward player
	var distance = current.distance_to(target)
	var move_amount = JAVELIN_RETURN_SPEED * get_process_delta_time()
	if move_amount >= distance:
		javelin_visual.global_position = target
	else:
		javelin_visual.global_position = current + new_direction * move_amount

func _javelin_damage_loop(_direction: Vector2, total_time: float, is_outward: bool):
	var checks = int(total_time * 20)  # Check ~20 times per second
	var check_interval = total_time / checks
	var damage_mult = JAVELIN_DAMAGE_MULT if is_outward else JAVELIN_RETURN_DAMAGE_MULT

	for i in range(checks):
		await get_tree().create_timer(check_interval).timeout

		if not is_instance_valid(self) or not is_instance_valid(javelin_visual):
			return

		var javelin_pos = javelin_visual.global_position
		var enemies = get_tree().get_nodes_in_group("enemies")

		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if enemy in javelin_hit_enemies:
				continue

			var dist = enemy.global_position.distance_to(javelin_pos)
			if dist < 60.0:  # Hit radius
				javelin_hit_enemies.append(enemy)

				var javelin_damage = damage * damage_mult * damage_multiplier
				if enemy.has_method("take_damage"):
					enemy.take_damage(javelin_damage, javelin_pos, 300.0, 0.15, player_reference)
					dealt_damage.emit(enemy, javelin_damage)

				# Pierce visual
				_create_pierce_effect(enemy.global_position)

				# Slight screen shake on hit
				if DamageNumberManager:
					DamageNumberManager.shake(0.1)

func _create_javelin_trail(duration: float):
	var trail_count = int(duration * 15)

	for i in range(trail_count):
		_spawn_javelin_trail_segment(i * (duration / trail_count))

func _spawn_javelin_trail_segment(delay: float):
	await get_tree().create_timer(delay).timeout

	if not is_instance_valid(self) or not is_instance_valid(javelin_visual):
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Shader-based javelin trail
	var trail = ColorRect.new()
	trail.size = Vector2(60, 14)
	trail.pivot_offset = Vector2(0, 7)
	scene.add_child(trail)
	trail.global_position = javelin_visual.global_position
	trail.rotation = javelin_visual.rotation

	var mat = ShaderMaterial.new()
	mat.shader = thrust_shader
	mat.set_shader_parameter("thrust_color", SPEAR_THRUST_COLOR)
	mat.set_shader_parameter("tip_color", SPEAR_ACCENT_COLOR)
	mat.set_shader_parameter("glow_intensity", 2.5)
	mat.set_shader_parameter("sharpness", 2.5)
	mat.set_shader_parameter("progress", 0.0)
	trail.material = mat

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.18)
	tween.tween_callback(trail.queue_free)

func _create_throw_effect(pos: Vector2, direction: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Burst of particles in throw direction
	for i in range(6):
		var particle = ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.color = SPEAR_ACCENT_COLOR
		particle.pivot_offset = Vector2(4, 4)
		scene.add_child(particle)
		particle.global_position = pos

		var angle = direction.angle() + randf_range(-0.4, 0.4)
		var dir = Vector2.from_angle(angle)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", pos + dir * 60, 0.15)
		tween.tween_property(particle, "modulate:a", 0.0, 0.15)
		tween.tween_callback(particle.queue_free)

func _create_impact_flash(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Shader-based flash at max range
	var flash = ColorRect.new()
	flash.size = Vector2(100, 100)
	flash.pivot_offset = Vector2(50, 50)
	flash.global_position = pos - Vector2(50, 50)

	var mat = ShaderMaterial.new()
	mat.shader = spark_shader
	mat.set_shader_parameter("spark_color", SPEAR_ACCENT_COLOR)
	mat.set_shader_parameter("hot_color", Color(1.0, 1.0, 0.9))
	mat.set_shader_parameter("spark_count", 6.0)
	mat.set_shader_parameter("rotation_speed", 8.0)
	mat.set_shader_parameter("progress", 0.0)
	flash.material = mat

	scene.add_child(flash)

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.2)
	tween.tween_callback(flash.queue_free)

	if DamageNumberManager:
		DamageNumberManager.shake(0.2)

func _cleanup_javelin():
	if is_instance_valid(javelin_visual):
		javelin_visual.queue_free()
		javelin_visual = null

	is_javelin_thrown = false
	javelin_hit_enemies.clear()
	visible = true

	_end_skill_invulnerability()

	# Catch effect when spear returns
	if player_reference and is_instance_valid(player_reference):
		_create_catch_effect(player_reference.global_position)

func _create_catch_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Small flash on catch
	for i in range(4):
		var spark = ColorRect.new()
		spark.size = Vector2(6, 6)
		spark.color = SPEAR_ACCENT_COLOR
		spark.pivot_offset = Vector2(3, 3)
		scene.add_child(spark)
		spark.global_position = pos

		var angle = (TAU / 4) * i
		var dir = Vector2.from_angle(angle)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", pos + dir * 25, 0.1)
		tween.tween_property(spark, "modulate:a", 0.0, 0.1)
		tween.tween_callback(spark.queue_free)

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
