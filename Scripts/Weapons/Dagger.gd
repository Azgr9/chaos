# SCRIPT: Dagger.gd
# ATTACH TO: Dagger (Node2D) root node in Dagger.tscn
# LOCATION: res://Scripts/Weapons/Dagger.gd
# Fast dagger - 3 hits per click, can walk while attacking, Dagger Storm skill

class_name Dagger
extends MeleeWeapon

# ============================================
# DAGGER-SPECIFIC STATE
# ============================================
var is_dagger_storming: bool = false

# Dagger Storm settings
const STORM_DAGGER_COUNT: int = 12
const STORM_SPREAD: float = 30.0  # Degrees spread
const STORM_DAMAGE_MULT: float = 0.8
const STORM_SPEED: float = 800.0
const STORM_RANGE: float = 400.0

# Triple strike settings
const STRIKES_PER_CLICK: int = 3
const STRIKE_DELAY: float = 0.06  # Delay between each strike
var _pending_strikes: int = 0
var _strike_direction: Vector2 = Vector2.RIGHT

# Visual colors - Dark purple/shadow themed
const DAGGER_BLADE_COLOR: Color = Color(0.6, 0.55, 0.7)  # Steel with purple tint
const DAGGER_SHADOW_COLOR: Color = Color(0.3, 0.1, 0.4, 0.8)  # Dark purple
const DAGGER_TRAIL_COLOR: Color = Color(0.5, 0.2, 0.6, 0.7)  # Purple trail
const DAGGER_GLOW_COLOR: Color = Color(0.7, 0.4, 0.9)  # Violet glow

# Shaders
var shadow_shader: Shader = preload("res://Shaders/Weapons/SwingTrail.gdshader")

func _weapon_ready():
	# Dagger - very fast, moderate damage, combo-focused
	damage = 8.0
	attack_duration = 0.10  # Very fast
	attack_cooldown = 0.08  # Quick recovery for triple strike
	swing_arc = 90.0  # Narrow arc
	weapon_length = 55.0  # Short reach
	weapon_color = DAGGER_BLADE_COLOR
	skill_cooldown = 4.0  # Short cooldown

	# Cone Hitbox - short range, focused
	attack_range = 110.0
	attack_cone_angle = 75.0

	# Attack Speed Limits (fast weapon)
	max_attacks_per_second = 8.0  # Very fast for triple strikes
	min_cooldown = 0.06

	# Idle - Dagger at the ready
	idle_rotation = 35.0
	idle_position = Vector2(4, -2)
	idle_scale = Vector2(0.55, 0.55)

	# Light knockback
	base_knockback = 100.0
	finisher_knockback = 200.0

	# Quick combos
	combo_window = 1.5
	combo_finisher_multiplier = 2.0
	combo_hits = 4

	# Walk animation - light, swift
	walk_bob_amount = 4.0
	walk_sway_amount = 8.0
	walk_anim_speed = 1.5

	_setup_idle_state()

func _get_attack_pattern(attack_index: int) -> String:
	# Dagger: quick alternating stabs
	match attack_index % 4:
		0: return "stab"
		1: return "horizontal"
		2: return "stab"
		3: return "horizontal_reverse"
		_: return "stab"

func _get_hit_color(combo_finisher: bool, dash_attack: bool, crit: bool) -> Color:
	if crit:
		return Color.RED
	elif combo_finisher:
		return DAGGER_GLOW_COLOR
	elif dash_attack or is_dagger_storming:
		return DAGGER_SHADOW_COLOR
	return DAGGER_BLADE_COLOR

# Override attack to do triple strike
func attack(direction: Vector2, player_damage_multiplier: float = 1.0) -> bool:
	if is_dagger_storming:
		return false

	# If already doing triple strike, don't start another
	if _pending_strikes > 0:
		return false

	# Start triple strike sequence
	_pending_strikes = STRIKES_PER_CLICK
	_strike_direction = direction
	damage_multiplier = player_damage_multiplier

	_execute_triple_strike()
	return true

func _execute_triple_strike():
	for i in range(STRIKES_PER_CLICK):
		if not is_instance_valid(self) or not player_reference:
			break

		# Slight angle variation for each strike
		var angle_offset = (i - 1) * 0.15  # -0.15, 0, 0.15
		var strike_dir = _strike_direction.rotated(angle_offset)

		# Perform single attack
		_perform_single_strike(strike_dir, i)

		# Wait between strikes
		if i < STRIKES_PER_CLICK - 1:
			await get_tree().create_timer(STRIKE_DELAY).timeout

	_pending_strikes = 0

func _perform_single_strike(direction: Vector2, strike_index: int):
	if not can_attack or is_attacking:
		return

	is_attacking = true
	can_attack = false
	hits_this_swing.clear()
	current_attack_direction = direction

	# Increment combo
	combo_count = (combo_count % combo_hits) + 1
	combo_timer = combo_window

	var pattern = _get_attack_pattern(strike_index)
	var _is_finisher = strike_index == STRIKES_PER_CLICK - 1 and combo_count == combo_hits

	_perform_attack_animation(pattern, attack_duration, false)
	_create_dagger_slash_effect(strike_index)

	# Start cooldown timer
	attack_timer.start(attack_cooldown)

	# Brief active frames
	await get_tree().create_timer(attack_duration * 0.8).timeout

	if is_instance_valid(self):
		is_attacking = false

func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	super._perform_attack_animation(pattern, duration, is_dash_attack)

func _create_dagger_slash_effect(strike_index: int = 0):
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Pixel art style slash - vary color by strike
	var slash_color = DAGGER_TRAIL_COLOR
	if strike_index == STRIKES_PER_CLICK - 1:
		slash_color = DAGGER_GLOW_COLOR

	# Create pixelated slash marks
	for i in range(3):
		var slash = ColorRect.new()
		# Square pixel blocks for retro look
		var pixel_size = 6.0
		slash.size = Vector2(pixel_size, pixel_size)
		slash.pivot_offset = Vector2(pixel_size / 2, pixel_size / 2)
		slash.color = slash_color
		scene.add_child(slash)

		# Position along slash line
		var offset = (i - 1) * 12.0
		var perpendicular = current_attack_direction.rotated(PI / 2)
		slash.global_position = global_position + current_attack_direction * (20 + i * 8) + perpendicular * offset

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(slash, "global_position", slash.global_position + current_attack_direction * 25, 0.1)
		tween.tween_property(slash, "modulate:a", 0.0, 0.12)
		tween.tween_callback(slash.queue_free)

	# Additional pixel sparks for final strike
	if strike_index == STRIKES_PER_CLICK - 1:
		for j in range(4):
			var spark = ColorRect.new()
			spark.size = Vector2(4, 4)
			spark.pivot_offset = Vector2(2, 2)
			spark.color = DAGGER_GLOW_COLOR
			scene.add_child(spark)
			spark.global_position = global_position + current_attack_direction * 30

			var angle = randf() * TAU
			var dir = Vector2.from_angle(angle)
			var s_tween = TweenHelper.new_tween()
			s_tween.set_parallel(true)
			s_tween.tween_property(spark, "global_position", spark.global_position + dir * 30, 0.15)
			s_tween.tween_property(spark, "modulate:a", 0.0, 0.18)
			s_tween.tween_callback(spark.queue_free)

func _on_combo_finisher_hit(_target: Node2D):
	DamageNumberManager.shake(0.25)
	_create_flurry_effect()

func _create_flurry_effect():
	if not player_reference:
		return

	var hit_pos = player_reference.global_position + current_attack_direction * 50
	var scene = get_tree().current_scene
	if not scene:
		return

	# Pixel art style flurry - square pixel bursts
	for i in range(12):
		var pixel = ColorRect.new()
		# Small square pixels
		var psize = 6.0 if i < 6 else 4.0
		pixel.size = Vector2(psize, psize)
		pixel.pivot_offset = Vector2(psize / 2, psize / 2)
		pixel.color = DAGGER_GLOW_COLOR if i < 6 else DAGGER_TRAIL_COLOR
		scene.add_child(pixel)
		pixel.global_position = hit_pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))

		var angle = randf() * TAU
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(30, 60)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(pixel, "global_position", pixel.global_position + dir * dist, 0.15)
		tween.tween_property(pixel, "modulate:a", 0.0, 0.18)
		tween.tween_callback(pixel.queue_free)

# ============================================
# DAGGER STORM - Throw a barrage of daggers forward!
# ============================================
func _is_async_skill() -> bool:
	return true

func _perform_skill() -> bool:
	if not player_reference or is_dagger_storming:
		return false

	is_dagger_storming = true
	_execute_dagger_storm()
	return true

func _execute_dagger_storm():
	var player = player_reference
	if not is_instance_valid(player):
		is_dagger_storming = false
		_end_skill_invulnerability()
		return

	var self_ref = weakref(self)
	var player_ref = weakref(player)
	var direction = (player.get_global_mouse_position() - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	var scene = get_tree().current_scene
	if not scene:
		is_dagger_storming = false
		_end_skill_invulnerability()
		return

	# Weapon glow
	if sprite:
		sprite.color = DAGGER_GLOW_COLOR

	# Screen shake
	DamageNumberManager.shake(0.4)

	# Throw daggers in rapid succession
	var spread_step = deg_to_rad(STORM_SPREAD) / (STORM_DAGGER_COUNT - 1)
	var start_angle = direction.angle() - deg_to_rad(STORM_SPREAD / 2)

	for i in range(STORM_DAGGER_COUNT):
		if not self_ref.get_ref() or not player_ref.get_ref():
			break

		var dagger_angle = start_angle + spread_step * i + randf_range(-0.05, 0.05)
		var dagger_dir = Vector2.from_angle(dagger_angle)

		_throw_dagger(player.global_position, dagger_dir, scene, player_ref)

		# Small delay between throws for visual effect
		await get_tree().create_timer(0.03).timeout

	# Wait for daggers to travel
	await get_tree().create_timer(0.3).timeout

	# Reset
	if self_ref.get_ref():
		is_dagger_storming = false
		if sprite:
			sprite.color = weapon_color
		_end_skill_invulnerability()

func _throw_dagger(start_pos: Vector2, direction: Vector2, scene: Node, player_ref: WeakRef):
	# Create dagger projectile - pixel art style
	var dagger = Node2D.new()
	dagger.global_position = start_pos
	dagger.rotation = direction.angle()
	scene.add_child(dagger)

	# Pixel art dagger blade - 3 squares in a row
	for i in range(3):
		var pixel = ColorRect.new()
		pixel.size = Vector2(6, 6)
		pixel.pivot_offset = Vector2(3, 3)
		pixel.position = Vector2(-3 + i * 6, -3)
		pixel.color = DAGGER_BLADE_COLOR if i < 2 else DAGGER_GLOW_COLOR
		dagger.add_child(pixel)

	# Trail pixel behind
	var trail = ColorRect.new()
	trail.size = Vector2(4, 4)
	trail.pivot_offset = Vector2(2, 2)
	trail.position = Vector2(-11, -2)
	trail.color = DAGGER_GLOW_COLOR
	trail.modulate.a = 0.7
	dagger.add_child(trail)

	# Animate flying
	var end_pos = start_pos + direction * STORM_RANGE
	var travel_time = STORM_RANGE / STORM_SPEED

	# Check for hits during travel
	_dagger_travel(dagger, start_pos, direction, travel_time, player_ref)

	var tween = TweenHelper.new_tween()
	tween.tween_property(dagger, "global_position", end_pos, travel_time)
	tween.tween_callback(func():
		if is_instance_valid(dagger):
			_create_dagger_hit_effect(dagger.global_position)
			dagger.queue_free()
	)

func _dagger_travel(dagger: Node2D, _start_pos: Vector2, _direction: Vector2, total_time: float, player_ref: WeakRef):
	var hit_enemies: Array = []
	var checks = int(total_time * 30)
	var check_interval = total_time / checks

	for i in range(checks):
		if not is_instance_valid(dagger):
			return

		await get_tree().create_timer(check_interval).timeout

		if not is_instance_valid(dagger):
			return

		var dagger_pos = dagger.global_position
		var enemies = get_tree().get_nodes_in_group("enemies")
		var player = player_ref.get_ref()

		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if enemy in hit_enemies:
				continue
			if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
				continue

			var dist = enemy.global_position.distance_to(dagger_pos)
			if dist < 30.0:
				hit_enemies.append(enemy)

				var dagger_damage = damage * STORM_DAMAGE_MULT * damage_multiplier
				if enemy.has_method("take_damage") and player:
					enemy.take_damage(dagger_damage, dagger_pos, 150.0, 0.05, player)
					dealt_damage.emit(enemy, dagger_damage)

				_create_dagger_hit_effect(enemy.global_position)
				DamageNumberManager.shake(0.1)

func _create_dagger_hit_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Pixel art hit effect - expanding pixel ring
	for i in range(4):
		var pixel = ColorRect.new()
		pixel.size = Vector2(6, 6)
		pixel.pivot_offset = Vector2(3, 3)
		pixel.color = DAGGER_GLOW_COLOR
		scene.add_child(pixel)
		pixel.global_position = pos - Vector2(3, 3)

		var angle = (TAU / 4) * i + PI / 4
		var dir = Vector2.from_angle(angle)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(pixel, "global_position", pos + dir * 20 - Vector2(3, 3), 0.1)
		tween.tween_property(pixel, "modulate:a", 0.0, 0.12)
		tween.tween_callback(pixel.queue_free)

	# Center flash pixel
	var center = ColorRect.new()
	center.size = Vector2(8, 8)
	center.pivot_offset = Vector2(4, 4)
	center.color = Color.WHITE
	scene.add_child(center)
	center.global_position = pos - Vector2(4, 4)

	var c_tween = TweenHelper.new_tween()
	c_tween.tween_property(center, "modulate:a", 0.0, 0.08)
	c_tween.tween_callback(center.queue_free)

# Dagger allows movement while attacking - override player movement block
func is_blocking_movement() -> bool:
	return false  # Never block movement
