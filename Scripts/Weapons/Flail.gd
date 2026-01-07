# SCRIPT: Flail.gd
# ATTACH TO: Flail (Node2D) root node in Flail.tscn
# LOCATION: res://Scripts/Weapons/Flail.gd
# Heavy chain flail with wide swings and Whirlwind skill

class_name Flail
extends MeleeWeapon

# ============================================
# FLAIL-SPECIFIC STATE
# ============================================
var is_whirlwinding: bool = false
var _whirlwind_tween: Tween = null
var whirlwind_hits: Array = []

# Whirlwind settings
const WHIRLWIND_DURATION: float = 1.2
const WHIRLWIND_SPINS: int = 3
const WHIRLWIND_RADIUS: float = 200.0
const WHIRLWIND_DAMAGE_PER_HIT: float = 0.6  # 60% of base per spin hit

# Visual colors - Dark iron/bronze themed
const FLAIL_HEAD_COLOR: Color = Color(0.45, 0.35, 0.25)  # Dark bronze
const FLAIL_CHAIN_COLOR: Color = Color(0.5, 0.5, 0.55)  # Steel chain
const FLAIL_SPIKE_COLOR: Color = Color(0.35, 0.3, 0.25)  # Dark spikes
const FLAIL_GLOW_COLOR: Color = Color(0.8, 0.6, 0.3)  # Bronze glow
const FLAIL_TRAIL_COLOR: Color = Color(0.6, 0.45, 0.25, 0.7)  # Bronze trail

# Shaders
var impact_shader: Shader = preload("res://Shaders/Weapons/ImpactShockwave.gdshader")
var swing_shader: Shader = preload("res://Shaders/Weapons/SwingTrail.gdshader")

func _weapon_ready():
	# Flail - slow, wide, powerful swings
	damage = 18.0
	attack_duration = 0.5  # Slow windup
	attack_cooldown = 0.65  # Long recovery
	swing_arc = 180.0  # Very wide arc
	weapon_length = 150.0  # Long reach due to chain
	weapon_color = FLAIL_HEAD_COLOR
	skill_cooldown = 14.0

	# Cone Hitbox - wide area
	attack_range = 200.0
	attack_cone_angle = 150.0  # Very wide

	# Attack Speed Limits (slow heavy weapon)
	max_attacks_per_second = 1.8
	min_cooldown = 0.45

	# Idle - Flail hanging low
	idle_rotation = -60.0
	idle_position = Vector2(-8, 8)
	idle_scale = Vector2(0.8, 0.8)

	# Heavy knockback
	base_knockback = 600.0
	finisher_knockback = 1000.0

	# Slow combo
	combo_window = 2.5
	combo_finisher_multiplier = 2.0
	combo_hits = 2  # Only 2-hit combo (but powerful)

	# Walk animation - heavy, swaying
	walk_bob_amount = 15.0
	walk_sway_amount = 20.0
	walk_anim_speed = 0.6

	_setup_idle_state()

func _get_attack_pattern(attack_index: int) -> String:
	# Flail: overhead slam -> horizontal sweep
	match attack_index:
		1: return "overhead"
		2: return "horizontal"
		_: return "overhead"

func _get_hit_color(combo_finisher: bool, dash_attack: bool, crit: bool) -> Color:
	if crit:
		return Color.RED
	elif combo_finisher:
		return FLAIL_GLOW_COLOR
	elif dash_attack or is_whirlwinding:
		return Color(0.9, 0.7, 0.4)
	return FLAIL_HEAD_COLOR

func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	# Kill existing tween
	if active_attack_tween:
		active_attack_tween.kill()

	var is_finisher = is_combo_finisher()

	if is_finisher:
		sprite.color = FLAIL_GLOW_COLOR
	elif is_dash_attack:
		sprite.color = Color.CYAN

	match pattern:
		"overhead":
			_animate_flail_slam(duration, is_dash_attack)
		"horizontal":
			_animate_flail_sweep(duration, is_dash_attack)
		_:
			_animate_flail_slam(duration, is_dash_attack)

func _animate_flail_slam(duration: float, _is_dash_attack: bool):
	active_attack_tween = TweenHelper.new_tween()

	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	# High raise for slam
	var raise_angle = base_angle - 140
	var slam_angle = base_angle + 30

	pivot.rotation = deg_to_rad(raise_angle)
	pivot.position = Vector2.ZERO

	# Long windup - raise high
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(raise_angle - 20), duration * 0.35)

	# Brief pause at peak
	active_attack_tween.tween_interval(duration * 0.05)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(is_combo_finisher(), false))
	active_attack_tween.tween_callback(_create_flail_trail)

	# Fast slam down
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(slam_angle), duration * 0.25)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	# Ground impact
	active_attack_tween.tween_callback(_create_ground_impact)
	active_attack_tween.tween_interval(duration * 0.1)

	# Recovery
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(slam_angle + 10), duration * 0.15)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _animate_flail_sweep(duration: float, _is_dash_attack: bool):
	active_attack_tween = TweenHelper.new_tween()

	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0
	var half_arc = 100.0

	var start_angle = base_angle - half_arc
	var end_angle = base_angle + half_arc

	pivot.rotation = deg_to_rad(start_angle)
	pivot.position = Vector2.ZERO

	# Windup - pull back
	var windup_angle = start_angle - 20
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(windup_angle), duration * 0.25)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(is_combo_finisher(), false))
	active_attack_tween.tween_callback(_create_flail_trail)

	# Wide sweep
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(end_angle), duration * 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Follow through
	var followthrough = end_angle + 25
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(followthrough), duration * 0.15)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _create_flail_trail():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Heavy arc trail
	var trail = ColorRect.new()
	trail.size = Vector2(weapon_length * 1.1, 30)
	trail.pivot_offset = Vector2(0, 15)
	scene.add_child(trail)
	trail.global_position = global_position
	trail.rotation = pivot.rotation

	var mat = ShaderMaterial.new()
	mat.shader = swing_shader
	mat.set_shader_parameter("trail_color", FLAIL_TRAIL_COLOR)
	mat.set_shader_parameter("glow_color", FLAIL_GLOW_COLOR)
	mat.set_shader_parameter("glow_intensity", 2.5)
	mat.set_shader_parameter("taper_amount", 0.4)
	mat.set_shader_parameter("progress", 0.0)
	trail.material = mat

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.3)
	tween.tween_callback(trail.queue_free)

func _create_ground_impact():
	if not player_reference:
		return

	var impact_pos = player_reference.global_position + current_attack_direction * 80
	var scene = get_tree().current_scene
	if not scene:
		return

	# Shockwave ring
	var ring = ColorRect.new()
	ring.size = Vector2(160, 160)
	ring.pivot_offset = Vector2(80, 80)
	ring.global_position = impact_pos - Vector2(80, 80)

	var mat = ShaderMaterial.new()
	mat.shader = impact_shader
	mat.set_shader_parameter("wave_color", Color(FLAIL_GLOW_COLOR.r, FLAIL_GLOW_COLOR.g, FLAIL_GLOW_COLOR.b, 0.7))
	mat.set_shader_parameter("ring_thickness", 0.15)
	mat.set_shader_parameter("inner_glow", 1.2)
	mat.set_shader_parameter("progress", 0.0)
	ring.material = mat

	scene.add_child(ring)

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.35)
	tween.tween_callback(ring.queue_free)

	# Debris particles
	for i in range(8):
		var debris = ColorRect.new()
		debris.size = Vector2(randf_range(8, 14), randf_range(8, 14))
		debris.color = Color(0.4, 0.35, 0.3)
		debris.pivot_offset = debris.size / 2
		scene.add_child(debris)
		debris.global_position = impact_pos + Vector2(randf_range(-20, 20), randf_range(-10, 10))

		var angle = randf_range(-PI * 0.7, -PI * 0.3)
		var dir = Vector2.from_angle(angle)
		var end_pos = debris.global_position + dir * randf_range(50, 100)

		var d_tween = TweenHelper.new_tween()
		d_tween.set_parallel(true)
		d_tween.tween_property(debris, "global_position", end_pos, 0.4)
		d_tween.tween_property(debris, "global_position:y", end_pos.y + 60, 0.4).set_delay(0.2)
		d_tween.tween_property(debris, "rotation", randf_range(-TAU, TAU), 0.4)
		d_tween.tween_property(debris, "modulate:a", 0.0, 0.4)
		d_tween.tween_callback(debris.queue_free)

	# Screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.4)

func _on_combo_finisher_hit(_target: Node2D):
	if DamageNumberManager:
		DamageNumberManager.shake(0.5)

# ============================================
# WHIRLWIND SKILL
# ============================================

func _is_async_skill() -> bool:
	return true

func _perform_skill() -> bool:
	if not player_reference:
		return false

	is_whirlwinding = true
	whirlwind_hits.clear()
	_execute_whirlwind()
	return true

func _execute_whirlwind():
	var player = player_reference
	if not is_instance_valid(player):
		is_whirlwinding = false
		_end_skill_invulnerability()
		return

	# Player is invulnerable during whirlwind
	player.is_invulnerable = true

	# Visual effect - spin the player slightly
	player.modulate = Color(0.9, 0.8, 0.6, 1.0)

	# Start spinning animation
	_animate_whirlwind_visual()

	# Damage loop
	_whirlwind_damage_loop(player)

func _animate_whirlwind_visual():
	if not player_reference or not is_instance_valid(player_reference):
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Create spinning visual effect
	for spin in range(WHIRLWIND_SPINS):
		var delay = (WHIRLWIND_DURATION / WHIRLWIND_SPINS) * spin

		# Ring effect for each spin
		var ring_timer = get_tree().create_timer(delay)
		var flail_ref = weakref(self)
		var player_ref = weakref(player_reference)

		ring_timer.timeout.connect(func():
			var f = flail_ref.get_ref()
			var p = player_ref.get_ref()
			if f and p and is_instance_valid(p) and is_instance_valid(f):
				f._create_whirlwind_ring(p.global_position)
		)

	# Rotate the weapon visually
	if _whirlwind_tween and _whirlwind_tween.is_valid():
		_whirlwind_tween.kill()

	_whirlwind_tween = TweenHelper.new_tween()
	_whirlwind_tween.tween_property(pivot, "rotation", pivot.rotation + TAU * WHIRLWIND_SPINS, WHIRLWIND_DURATION)\
		.set_trans(Tween.TRANS_LINEAR)

func _whirlwind_damage_loop(player: Node2D):
	var damage_ticks = WHIRLWIND_SPINS * 2  # Damage twice per spin
	var tick_delay = WHIRLWIND_DURATION / damage_ticks

	for tick in range(damage_ticks):
		await get_tree().create_timer(tick_delay).timeout

		if not is_instance_valid(self) or not is_instance_valid(player):
			break

		if not is_whirlwinding:
			break

		# Find and damage nearby enemies
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if enemy.is_in_group("converted_minion"):
				continue

			var dist = enemy.global_position.distance_to(player.global_position)
			if dist <= WHIRLWIND_RADIUS:
				# Only hit each enemy once per spin (use tick / 2 as spin index)
				@warning_ignore("integer_division")
				var spin_index: int = tick / 2
				var hit_key = str(enemy.get_instance_id()) + "_" + str(spin_index)

				if hit_key in whirlwind_hits:
					continue

				whirlwind_hits.append(hit_key)

				var final_damage = damage * damage_multiplier * WHIRLWIND_DAMAGE_PER_HIT
				if enemy.has_method("take_damage"):
					enemy.take_damage(final_damage, player.global_position, 300.0, 0.1, player)
					dealt_damage.emit(enemy, final_damage)
					_create_whirlwind_hit_effect(enemy.global_position)

	# End whirlwind
	_on_whirlwind_finished(player)

func _on_whirlwind_finished(player: Node2D):
	if is_instance_valid(player):
		player.is_invulnerable = false
		player.modulate = Color.WHITE

	is_whirlwinding = false
	whirlwind_hits.clear()
	_whirlwind_tween = null
	_end_skill_invulnerability()

	# Return to idle
	_setup_idle_state()

func _create_whirlwind_ring(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	var ring = ColorRect.new()
	ring.size = Vector2(WHIRLWIND_RADIUS * 2, WHIRLWIND_RADIUS * 2)
	ring.pivot_offset = Vector2(WHIRLWIND_RADIUS, WHIRLWIND_RADIUS)
	ring.global_position = pos - Vector2(WHIRLWIND_RADIUS, WHIRLWIND_RADIUS)

	var mat = ShaderMaterial.new()
	mat.shader = impact_shader
	mat.set_shader_parameter("wave_color", Color(FLAIL_GLOW_COLOR.r, FLAIL_GLOW_COLOR.g, FLAIL_GLOW_COLOR.b, 0.5))
	mat.set_shader_parameter("ring_thickness", 0.2)
	mat.set_shader_parameter("inner_glow", 1.0)
	mat.set_shader_parameter("progress", 0.0)
	ring.material = mat

	scene.add_child(ring)

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.4)
	tween.tween_callback(ring.queue_free)

func _create_whirlwind_hit_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Small impact spark
	var spark = ColorRect.new()
	spark.size = Vector2(20, 20)
	spark.color = FLAIL_GLOW_COLOR
	spark.pivot_offset = Vector2(10, 10)
	scene.add_child(spark)
	spark.global_position = pos - Vector2(10, 10)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(spark, "modulate:a", 0.0, 0.1)
	tween.tween_callback(spark.queue_free)

# Override attack to block during whirlwind
func attack(direction: Vector2, player_damage_multiplier: float = 1.0) -> bool:
	if is_whirlwinding:
		return false
	return super.attack(direction, player_damage_multiplier)
