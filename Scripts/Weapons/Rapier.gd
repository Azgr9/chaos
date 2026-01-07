# SCRIPT: Rapier.gd
# ATTACH TO: Rapier (Node2D) root node in Rapier.tscn
# LOCATION: res://Scripts/Weapons/Rapier.gd
# Fast, precise thrusting weapon - pure stab attacks with extended range

class_name Rapier
extends MeleeWeapon

# ============================================
# RAPIER-SPECIFIC STATE
# ============================================
var is_using_riposte: bool = false

# RIPOSTE skill - Quick dash forward with powerful thrust
const RIPOSTE_DISTANCE: float = 300.0
const RIPOSTE_TIME: float = 0.12
const RIPOSTE_DAMAGE_MULT: float = 3.0
const RIPOSTE_HIT_RADIUS: float = 80.0

# Visual colors - silver/steel with blue accents
const RAPIER_BLADE_COLOR: Color = Color(0.85, 0.88, 0.95)  # Polished silver-blue
const RAPIER_GUARD_COLOR: Color = Color(0.7, 0.6, 0.3)  # Gold guard
const RAPIER_THRUST_COLOR: Color = Color(0.5, 0.7, 1.0, 0.9)  # Blue thrust trail
const RAPIER_SPARK_COLOR: Color = Color(1.0, 1.0, 1.0)  # White sparks

func _weapon_ready():
	# Rapier - longest range melee, pure precision stabs
	damage = 7.0  # Lower per-hit but fastest attack speed
	attack_duration = 0.12  # Lightning fast stabs
	attack_cooldown = 0.15  # Minimal recovery
	swing_arc = 0.0  # No swing - pure stab
	weapon_length = 120.0  # Longest melee reach
	weapon_color = RAPIER_BLADE_COLOR

	# Idle - Rapier in fencing ready stance
	idle_rotation = 0.0
	idle_position = Vector2(10, 0)
	idle_scale = Vector2(0.4, 1.0)

	# Cone Hitbox
	attack_range = 140.0
	attack_cone_angle = 45.0

	# Attack Speed Limits (fastest melee weapon)
	max_attacks_per_second = 6.0
	min_cooldown = 0.10

	# Animation timing
	windup_ratio = 0.10
	active_ratio = 0.55
	allow_recovery_cancel = true

	# Combo settings - 5-hit combo
	combo_window = 1.0
	combo_extension_on_hit = 0.3
	combo_finisher_multiplier = 2.5
	combo_hits = 5

	# Lower knockback (precision, not power)
	base_knockback = 80.0
	finisher_knockback = 250.0
	knockback_stun = 0.08

	# Skill settings
	skill_cooldown = 5.0

	# Walk animation
	walk_bob_amount = 5.0
	walk_sway_amount = 8.0
	walk_anim_speed = 1.5

	_setup_idle_state()

func _get_attack_pattern(_attack_index: int) -> String:
	return "stab"

func _get_hit_color(combo_finisher: bool, dash_attack: bool, crit: bool) -> Color:
	if crit:
		return Color(1.0, 0.3, 0.3)
	elif combo_finisher:
		return Color(1.0, 0.85, 0.3)
	elif dash_attack or is_using_riposte:
		return RAPIER_THRUST_COLOR
	return RAPIER_BLADE_COLOR

# Override attack animation for rapier stab style
func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	if pattern == "stab":
		_animate_rapier_stab(duration, is_dash_attack)
	else:
		super._perform_attack_animation(pattern, duration, is_dash_attack)

func _animate_rapier_stab(duration: float, is_dash_attack: bool):
	if active_attack_tween:
		active_attack_tween.kill()
		active_attack_tween = null
		_is_in_active_frames = false

	active_attack_tween = TweenHelper.new_tween()

	var is_finisher = is_combo_finisher()
	var attack_num = get_attack_in_combo()

	# Base angle pointing at target
	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	# Slight angle variation
	var angle_offset = 0.0
	match attack_num:
		1: angle_offset = -5.0
		2: angle_offset = 5.0
		3: angle_offset = -3.0
		4: angle_offset = 4.0
		5: angle_offset = 0.0

	pivot.rotation = deg_to_rad(base_angle + angle_offset)
	pivot.position = Vector2.ZERO

	# Color
	if is_finisher:
		sprite.color = Color.GOLD
	elif is_dash_attack:
		sprite.color = RAPIER_THRUST_COLOR
	else:
		sprite.color = RAPIER_BLADE_COLOR

	var thrust_distance = 95.0
	if is_finisher:
		thrust_distance = 130.0
	elif is_dash_attack:
		thrust_distance = 110.0

	# Quick pullback
	var pullback = current_attack_direction * -15.0
	active_attack_tween.tween_property(pivot, "position", pullback, duration * 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(is_finisher, is_dash_attack))

	# Thrust forward
	var thrust_pos = current_attack_direction * thrust_distance
	active_attack_tween.tween_property(pivot, "position", thrust_pos, duration * 0.4)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# Create visual trail
	active_attack_tween.tween_callback(_create_stab_trail.bind(is_finisher))

	# Brief hold for finisher
	if is_finisher:
		active_attack_tween.tween_interval(duration * 0.1)

	# Return to ready
	active_attack_tween.tween_property(pivot, "position", Vector2.ZERO, duration * 0.2)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _create_stab_trail(is_finisher: bool):
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	var trail_color = Color(1.0, 0.9, 0.5, 0.9) if is_finisher else RAPIER_THRUST_COLOR
	var pixel_count = 8 if is_finisher else 5

	# Pixel art thrust trail - line of square pixels
	for i in range(pixel_count):
		var pixel = ColorRect.new()
		var psize = 6.0 if i < pixel_count / 2.0 else 4.0
		pixel.size = Vector2(psize, psize)
		pixel.pivot_offset = Vector2(psize / 2, psize / 2)
		pixel.color = trail_color if i < pixel_count - 2 else RAPIER_SPARK_COLOR
		scene.add_child(pixel)

		var dist = 25.0 + i * 12.0
		pixel.global_position = global_position + current_attack_direction * dist - Vector2(psize / 2, psize / 2)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(pixel, "global_position", pixel.global_position + current_attack_direction * 20, 0.08)
		tween.tween_property(pixel, "modulate:a", 0.0, 0.1)
		tween.tween_callback(pixel.queue_free)

	# Spark effect for finisher
	if is_finisher:
		_create_thrust_sparks()

func _create_thrust_sparks():
	var scene = get_tree().current_scene
	if not scene:
		return

	var hit_pos = global_position + current_attack_direction * 100

	# Pixel art sparks - small square pixels flying out
	for i in range(8):
		var spark = ColorRect.new()
		spark.size = Vector2(4, 4)
		spark.pivot_offset = Vector2(2, 2)
		spark.color = RAPIER_SPARK_COLOR
		spark.global_position = hit_pos - Vector2(2, 2)
		scene.add_child(spark)

		var angle = (TAU / 8) * i + randf_range(-0.3, 0.3)
		var dir = Vector2.from_angle(angle)
		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", hit_pos + dir * randf_range(25, 50) - Vector2(2, 2), 0.12)
		tween.tween_property(spark, "modulate:a", 0.0, 0.15)
		tween.tween_callback(spark.queue_free)

# ============================================
# RIPOSTE SKILL - Quick dash thrust
# ============================================
func _is_async_skill() -> bool:
	return true

func _perform_skill() -> bool:
	if not player_reference or is_using_riposte:
		return false

	is_using_riposte = true
	_execute_riposte()
	return true

func _execute_riposte():
	var player = player_reference
	if not is_instance_valid(player):
		is_using_riposte = false
		_end_skill_invulnerability()
		return

	# Make player invulnerable during riposte
	player.is_invulnerable = true

	# Get direction toward mouse
	var direction = (player.get_global_mouse_position() - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	var target_pos = _calculate_safe_position(player, direction)

	var scene = get_tree().current_scene
	if not scene:
		is_using_riposte = false
		player.is_invulnerable = false
		_end_skill_invulnerability()
		return

	# Show skill name
	_show_skill_text("RIPOSTE!", player.global_position + Vector2(0, -80))

	# Visual - transparency during dash
	player.modulate = Color(1, 1, 1, 0.5)

	# Weapon glow
	if sprite:
		sprite.color = Color(1.0, 0.9, 0.5)

	# Screen shake
	DamageNumberManager.shake(0.3)

	# Create trail effect
	_create_riposte_trail(player.global_position, direction, scene)

	# Perform dash
	var self_ref = weakref(self)
	var player_ref = weakref(player)
	var hit_enemies: Array = []

	var dash_tween = TweenHelper.new_tween()
	dash_tween.tween_property(player, "global_position", target_pos, RIPOSTE_TIME)\
		.set_trans(Tween.TRANS_LINEAR)

	# Damage during dash
	_riposte_damage_loop(player, direction, hit_enemies)

	await dash_tween.finished

	# Final thrust effect at end position
	if self_ref.get_ref() and player_ref.get_ref():
		_create_thrust_impact(player.global_position, direction, scene)
		DamageNumberManager.shake(0.25)

	# Reset
	if self_ref.get_ref():
		is_using_riposte = false
		if sprite:
			sprite.color = weapon_color

	if player_ref.get_ref():
		player.is_invulnerable = false
		player.modulate = Color.WHITE

	_end_skill_invulnerability()

func _calculate_safe_position(player: Node2D, direction: Vector2) -> Vector2:
	var desired = player.global_position + direction * RIPOSTE_DISTANCE

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(player.global_position, desired)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var exclude: Array = [player]
	exclude.append_array(get_tree().get_nodes_in_group("enemies"))
	query.exclude = exclude

	var result = space_state.intersect_ray(query)

	if result and result.has("position"):
		return result.position - direction * 16.0
	return desired

func _riposte_damage_loop(player: Node2D, _direction: Vector2, hit_enemies: Array):
	var checks = 5

	for i in range(checks):
		await get_tree().create_timer(RIPOSTE_TIME / checks).timeout

		if not is_instance_valid(self) or not is_instance_valid(player):
			return

		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if enemy in hit_enemies:
				continue
			if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
				continue

			if enemy.global_position.distance_to(player.global_position) < RIPOSTE_HIT_RADIUS:
				hit_enemies.append(enemy)
				var riposte_damage = damage * damage_multiplier * RIPOSTE_DAMAGE_MULT

				if enemy.has_method("take_damage"):
					enemy.take_damage(riposte_damage, player.global_position, 200.0, 0.1, player)
					dealt_damage.emit(enemy, riposte_damage)
					_create_hit_flash(enemy.global_position)

func _create_riposte_trail(start_pos: Vector2, direction: Vector2, scene: Node):
	# Pixel art dash trail - series of pixel blocks
	var pixel_count = 15
	var spacing = RIPOSTE_DISTANCE / pixel_count

	for i in range(pixel_count):
		var pixel = ColorRect.new()
		var psize = 8.0 if i % 3 == 0 else 6.0
		pixel.size = Vector2(psize, psize)
		pixel.pivot_offset = Vector2(psize / 2, psize / 2)
		pixel.color = RAPIER_THRUST_COLOR if i < pixel_count - 3 else RAPIER_SPARK_COLOR
		pixel.modulate.a = 0.8 - (float(i) / pixel_count) * 0.4
		scene.add_child(pixel)

		var pos = start_pos + direction * (i * spacing)
		pixel.global_position = pos - Vector2(psize / 2, psize / 2)

		var tween = TweenHelper.new_tween()
		tween.tween_property(pixel, "modulate:a", 0.0, 0.15 + i * 0.01)
		tween.tween_callback(pixel.queue_free)

	# Side pixel accents
	for i in range(6):
		var side_pixel = ColorRect.new()
		side_pixel.size = Vector2(4, 4)
		side_pixel.pivot_offset = Vector2(2, 2)
		side_pixel.color = Color(0.8, 0.9, 1.0, 0.6)
		scene.add_child(side_pixel)

		var perpendicular = direction.rotated(PI / 2)
		var side = (i % 2) * 2 - 1  # -1 or 1
		var pos = start_pos + direction * (i * spacing * 2) + perpendicular * (side * 12)
		side_pixel.global_position = pos - Vector2(2, 2)

		var s_tween = TweenHelper.new_tween()
		s_tween.tween_property(side_pixel, "modulate:a", 0.0, 0.12)
		s_tween.tween_callback(side_pixel.queue_free)

func _create_thrust_impact(pos: Vector2, direction: Vector2, scene: Node):
	# Pixel art impact - expanding pixel ring
	for i in range(8):
		var pixel = ColorRect.new()
		pixel.size = Vector2(6, 6)
		pixel.pivot_offset = Vector2(3, 3)
		pixel.color = RAPIER_THRUST_COLOR if i < 4 else RAPIER_SPARK_COLOR
		scene.add_child(pixel)
		pixel.global_position = pos - Vector2(3, 3)

		var angle = (TAU / 8) * i
		var dir = Vector2.from_angle(angle)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(pixel, "global_position", pos + dir * 40 - Vector2(3, 3), 0.12)
		tween.tween_property(pixel, "modulate:a", 0.0, 0.15)
		tween.tween_callback(pixel.queue_free)

	# Center flash
	var center = ColorRect.new()
	center.size = Vector2(12, 12)
	center.pivot_offset = Vector2(6, 6)
	center.color = Color.WHITE
	center.global_position = pos - Vector2(6, 6)
	scene.add_child(center)

	var c_tween = TweenHelper.new_tween()
	c_tween.tween_property(center, "modulate:a", 0.0, 0.1)
	c_tween.tween_callback(center.queue_free)

	# Thrust direction pixels
	for i in range(4):
		var thrust_pixel = ColorRect.new()
		thrust_pixel.size = Vector2(6, 6)
		thrust_pixel.pivot_offset = Vector2(3, 3)
		thrust_pixel.color = RAPIER_SPARK_COLOR
		thrust_pixel.global_position = pos - Vector2(3, 3)
		scene.add_child(thrust_pixel)

		var angle_offset = (i - 1.5) * 0.15
		var dir = Vector2.from_angle(direction.angle() + angle_offset)

		var t_tween = TweenHelper.new_tween()
		t_tween.set_parallel(true)
		t_tween.tween_property(thrust_pixel, "global_position", pos + dir * (50 + i * 10) - Vector2(3, 3), 0.1)
		t_tween.tween_property(thrust_pixel, "modulate:a", 0.0, 0.12)
		t_tween.tween_callback(thrust_pixel.queue_free)

func _create_hit_flash(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Pixel art hit flash - cross pattern
	for i in range(4):
		var pixel = ColorRect.new()
		pixel.size = Vector2(6, 6)
		pixel.pivot_offset = Vector2(3, 3)
		pixel.color = RAPIER_SPARK_COLOR
		scene.add_child(pixel)
		pixel.global_position = pos - Vector2(3, 3)

		var angle = (TAU / 4) * i
		var dir = Vector2.from_angle(angle)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(pixel, "global_position", pos + dir * 18 - Vector2(3, 3), 0.08)
		tween.tween_property(pixel, "modulate:a", 0.0, 0.1)
		tween.tween_callback(pixel.queue_free)

	# Center pixel
	var center = ColorRect.new()
	center.size = Vector2(8, 8)
	center.pivot_offset = Vector2(4, 4)
	center.color = Color.WHITE
	center.global_position = pos - Vector2(4, 4)
	scene.add_child(center)

	var c_tween = TweenHelper.new_tween()
	c_tween.tween_property(center, "modulate:a", 0.0, 0.06)
	c_tween.tween_callback(center.queue_free)

func _show_skill_text(text: String, pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", RAPIER_THRUST_COLOR)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = pos - Vector2(100, 0)
	label.custom_minimum_size = Vector2(200, 50)
	scene.add_child(label)

	var tween = TweenHelper.new_tween()
	tween.tween_property(label, "position:y", pos.y - 100, 0.5)
	tween.parallel().tween_property(label, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)

func _on_combo_finisher_hit(_target: Node2D):
	DamageNumberManager.shake(0.3)
	_create_thrust_sparks()

# Block attacks during skill
func attack(direction: Vector2, player_damage_multiplier: float = 1.0) -> bool:
	if is_using_riposte:
		return false
	return super.attack(direction, player_damage_multiplier)
