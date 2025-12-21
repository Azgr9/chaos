# SCRIPT: Rapier.gd
# ATTACH TO: Rapier (Node2D) root node in Rapier.tscn
# LOCATION: res://Scripts/Weapons/Rapier.gd
# Fast, precise thrusting weapon - pure stab attacks with extended range

class_name Rapier
extends MeleeWeapon

# ============================================
# RAPIER-SPECIFIC STATE
# ============================================
var is_flurrying: bool = false
const FLURRY_STABS: int = 8  # Many rapid stabs
const FLURRY_INTERVAL: float = 0.05  # Very fast flurry
const FLURRY_DAMAGE_MULTIPLIER: float = 0.4

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
	damage_type = DamageTypes.Type.BLEED  # Applies BLEED status effect
	idle_rotation = 25.0  # Angled forward, ready stance
	idle_scale = Vector2(0.4, 1.0)  # Thin and long

	# Attack Speed Limits (fastest melee weapon)
	max_attacks_per_second = 6.0  # Extremely fast
	min_cooldown = 0.10  # Can attack very rapidly

	# Animation timing - quick stabs
	windup_ratio = 0.10  # Very short windup
	active_ratio = 0.55  # Mostly active (thrust)
	allow_recovery_cancel = true

	# Combo settings - 5-hit combo for rapier mastery
	combo_window = 1.0
	combo_extension_on_hit = 0.3
	combo_finisher_multiplier = 2.5  # Big payoff for 5th hit
	combo_hits = 5

	# Lower knockback (precision, not power)
	base_knockback = 80.0
	finisher_knockback = 250.0
	knockback_stun = 0.08

	# Skill settings
	skill_cooldown = 4.0  # Short cooldown for aggressive play

	# Apply visual styling
	_setup_rapier_visuals()

func _setup_rapier_visuals():
	# Make the rapier look distinct - thin blade
	if sprite:
		sprite.color = RAPIER_BLADE_COLOR
		sprite.size = Vector2(100, 6)  # Long and thin
		sprite.position = Vector2(0, -3)

func _get_attack_pattern(_attack_index: int) -> String:
	# Rapier: ALL stabs, no swings - each stab slightly different
	return "rapier_stab"

func _get_hit_color(combo_finisher: bool, dash_attack: bool, crit: bool) -> Color:
	if crit:
		return Color(1.0, 0.3, 0.3)  # Red crit
	elif combo_finisher:
		return Color(1.0, 0.85, 0.3)  # Gold finisher
	elif dash_attack or is_flurrying:
		return RAPIER_THRUST_COLOR
	return RAPIER_BLADE_COLOR

# ============================================
# OVERRIDE ATTACK ANIMATION
# ============================================
func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	if pattern == "rapier_stab":
		_animate_precision_stab(duration, is_dash_attack)
	else:
		super._perform_attack_animation(pattern, duration, is_dash_attack)

# ============================================
# PRECISION STAB - The core rapier attack
# ============================================
func _animate_precision_stab(duration: float, is_dash_attack: bool):
	if active_attack_tween:
		active_attack_tween.kill()
		active_attack_tween = null
		# Ensure hitbox is disabled if previous attack was interrupted
		hit_box_collision.set_deferred("disabled", true)
		_is_in_active_frames = false

	active_attack_tween = TweenHelper.new_tween()

	var is_finisher = is_combo_finisher()
	var attack_num = get_attack_in_combo()

	# Base angle pointing at target
	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	# Slight angle variation for visual interest (alternates slightly)
	var angle_offset = 0.0
	match attack_num:
		1: angle_offset = -8.0  # Slightly up
		2: angle_offset = 5.0   # Slightly down
		3: angle_offset = -3.0  # Center-up
		4: angle_offset = 7.0   # Down
		5: angle_offset = 0.0   # Perfect center (finisher)

	var final_angle = base_angle + angle_offset

	# Calculate thrust distance based on attack type
	var thrust_distance: float
	if is_finisher:
		thrust_distance = 130.0  # Maximum lunge
	elif is_dash_attack:
		thrust_distance = 110.0
	else:
		thrust_distance = 95.0  # Normal stab - still long

	# Set starting position and rotation
	pivot.rotation = deg_to_rad(final_angle)
	pivot.position = Vector2.ZERO
	sprite.scale = Vector2(1.0, 1.0)

	# Color based on attack type
	if is_finisher:
		sprite.color = Color.GOLD
	elif is_dash_attack:
		sprite.color = RAPIER_THRUST_COLOR
	else:
		sprite.color = RAPIER_BLADE_COLOR

	# Phase 1: Quick pullback (very short)
	var pullback_distance = 15.0 if not is_finisher else 30.0
	var pullback_pos = current_attack_direction * -pullback_distance
	active_attack_tween.tween_property(pivot, "position", pullback_pos, duration * 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Enable hitbox at start of thrust
	active_attack_tween.tween_callback(_enable_hitbox.bind(is_finisher, is_dash_attack))

	# Phase 2: Lightning-fast thrust forward
	var thrust_pos = current_attack_direction * thrust_distance
	var thrust_time = duration * 0.40 if not is_finisher else duration * 0.35
	active_attack_tween.tween_property(pivot, "position", thrust_pos, thrust_time)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# Create thrust visual trail
	active_attack_tween.tween_callback(_create_stab_trail.bind(is_finisher))

	# Phase 3: Brief hold at extension (for finisher) or immediate return
	if is_finisher:
		active_attack_tween.tween_interval(duration * 0.10)
		# Slight forward movement for player on finisher
		if player_reference:
			var lunge_move = current_attack_direction * 40
			var lunge_target = player_reference.global_position + lunge_move
			active_attack_tween.parallel().tween_property(player_reference, "global_position", lunge_target, duration * 0.25)

	# Phase 4: Quick return to ready position
	active_attack_tween.tween_property(pivot, "position", Vector2.ZERO, duration * 0.20)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _create_stab_trail(is_finisher: bool):
	if not player_reference:
		return

	# Create sharp thrust line effect
	var trail_length = 80.0 if is_finisher else 50.0
	var trail_width = 4.0 if is_finisher else 2.0

	var trail = ColorRect.new()
	trail.size = Vector2(trail_width, trail_length)
	trail.color = RAPIER_THRUST_COLOR if not is_finisher else Color(1.0, 0.9, 0.4, 0.9)
	trail.pivot_offset = Vector2(trail_width / 2, trail_length / 2)
	get_tree().current_scene.add_child(trail)
	trail.global_position = global_position + current_attack_direction * 60
	trail.rotation = current_attack_direction.angle() + PI/2

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "scale", Vector2(0.3, 1.8), 0.06)
	tween.tween_property(trail, "modulate:a", 0.0, 0.10)
	tween.chain().tween_callback(trail.queue_free)

	# Additional spark effect for finisher
	if is_finisher:
		_create_thrust_sparks()

func _create_thrust_sparks():
	var hit_pos = global_position + current_attack_direction * 100

	for i in range(4):
		var spark = ColorRect.new()
		spark.size = Vector2(3, 12)
		spark.color = RAPIER_SPARK_COLOR
		spark.pivot_offset = Vector2(1.5, 6)
		get_tree().current_scene.add_child(spark)
		spark.global_position = hit_pos

		var angle = current_attack_direction.angle() + randf_range(-0.4, 0.4)
		var dir = Vector2.from_angle(angle)
		spark.rotation = angle

		var stween = TweenHelper.new_tween()
		stween.set_parallel(true)
		stween.tween_property(spark, "global_position", hit_pos + dir * 35, 0.08)
		stween.tween_property(spark, "modulate:a", 0.0, 0.10)
		stween.chain().tween_callback(spark.queue_free)

# ============================================
# FLURRY SKILL - Rapid multi-stab barrage
# ============================================
func _perform_skill() -> bool:
	if not player_reference or is_flurrying:
		return false

	is_flurrying = true
	_execute_flurry()
	return true

func _execute_flurry():
	# Validate before starting
	if not is_instance_valid(self) or not is_instance_valid(player_reference):
		is_flurrying = false
		return

	var direction = (player_reference.get_global_mouse_position() - player_reference.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	# Visual: rapier glows blue during flurry
	if is_instance_valid(self) and sprite:
		sprite.color = Color(0.4, 0.7, 1.0, 1.0)

	# Screen shake start
	DamageNumberManager.shake(0.15)

	for i in range(FLURRY_STABS):
		# Check validity before each stab
		if not is_instance_valid(self) or not is_instance_valid(player_reference):
			break

		_perform_flurry_stab(direction, i)

		# Store tree reference before await (tree could be null after await if freed)
		var tree = get_tree()
		if not tree:
			break
		await tree.create_timer(FLURRY_INTERVAL).timeout

		# Re-check validity after await
		if not is_instance_valid(self) or not is_instance_valid(player_reference):
			return

	# Final burst effect - validate everything
	if is_instance_valid(self) and is_instance_valid(player_reference):
		_create_flurry_finish_effect(direction)

	# Reset state - only if we still exist
	if is_instance_valid(self):
		is_flurrying = false
		if sprite:
			sprite.color = weapon_color

func _perform_flurry_stab(direction: Vector2, stab_index: int):
	if not is_instance_valid(player_reference):
		return

	# Alternating angle variation for machine-gun effect
	var angle_offset = -12.0 if (stab_index % 2 == 0) else 12.0
	angle_offset += randf_range(-5.0, 5.0)
	var stab_direction = direction.rotated(deg_to_rad(angle_offset))

	# Quick stab animation
	var base_angle = rad_to_deg(stab_direction.angle()) + 90.0
	pivot.rotation = deg_to_rad(base_angle)

	# Stab motion - extended reach
	var stab_distance = 90.0 + randf_range(-10, 10)
	var tween = TweenHelper.new_tween()
	tween.tween_property(pivot, "position", stab_direction * stab_distance, FLURRY_INTERVAL * 0.35)
	tween.tween_property(pivot, "position", Vector2.ZERO, FLURRY_INTERVAL * 0.35)

	# Create individual stab trail
	_create_mini_stab_trail(stab_direction)

	# Deal damage to enemies in front (extended cone)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not is_instance_valid(player_reference):
			continue

		var to_enemy = enemy.global_position - player_reference.global_position
		var distance = to_enemy.length()

		if distance < 150.0:  # Extended range for flurry
			var dot = to_enemy.normalized().dot(direction)
			if dot > 0.4:  # Wider cone for skill
				var flurry_damage = damage * damage_multiplier * FLURRY_DAMAGE_MULTIPLIER
				if enemy.has_method("take_damage"):
					enemy.take_damage(flurry_damage, player_reference.global_position, 50.0, 0.02, player_reference, damage_type)
					dealt_damage.emit(enemy, flurry_damage)

func _create_mini_stab_trail(stab_dir: Vector2):
	var trail = ColorRect.new()
	trail.size = Vector2(2, 40)
	trail.color = Color(0.5, 0.7, 1.0, 0.6)
	trail.pivot_offset = Vector2(1, 20)
	get_tree().current_scene.add_child(trail)
	trail.global_position = global_position + stab_dir * 50
	trail.rotation = stab_dir.angle() + PI/2

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "modulate:a", 0.0, 0.08)
	tween.chain().tween_callback(trail.queue_free)

func _create_flurry_finish_effect(direction: Vector2):
	# Final thrust line burst
	var hit_pos = global_position + direction * 100

	for i in range(8):
		var line = ColorRect.new()
		line.size = Vector2(2, 60)
		line.color = Color(0.6, 0.8, 1.0, 0.8)
		line.pivot_offset = Vector2(1, 30)
		get_tree().current_scene.add_child(line)
		line.global_position = hit_pos

		var angle = direction.angle() + (i - 3.5) * 0.15
		line.rotation = angle + PI/2

		var dir = Vector2.from_angle(angle)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(line, "global_position", hit_pos + dir * 50, 0.12)
		tween.tween_property(line, "scale:y", 0.3, 0.12)
		tween.tween_property(line, "modulate:a", 0.0, 0.12)
		tween.chain().tween_callback(line.queue_free)

	DamageNumberManager.shake(0.25)

func _on_combo_finisher_hit(target: Node2D):
	# Precision strike - screen shake and thrust effect
	DamageNumberManager.shake(0.3)

	var hit_pos = target.global_position if is_instance_valid(target) else player_reference.global_position + current_attack_direction * 80
	_create_precision_thrust_effect(hit_pos)

func _create_precision_thrust_effect(hit_pos: Vector2):
	# Large thrust line through target
	var thrust_line = ColorRect.new()
	thrust_line.size = Vector2(5, 140)
	thrust_line.color = Color(1.0, 0.95, 0.7, 0.9)
	thrust_line.pivot_offset = Vector2(2.5, 70)
	get_tree().current_scene.add_child(thrust_line)
	thrust_line.global_position = hit_pos
	thrust_line.rotation = current_attack_direction.angle() + PI/2

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(thrust_line, "scale", Vector2(0.2, 1.8), 0.08)
	tween.tween_property(thrust_line, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(thrust_line.queue_free)

	# Radial spark burst
	for i in range(8):
		var spark = ColorRect.new()
		spark.size = Vector2(3, 15)
		spark.color = RAPIER_SPARK_COLOR
		spark.pivot_offset = Vector2(1.5, 7.5)
		get_tree().current_scene.add_child(spark)
		spark.global_position = hit_pos

		var angle = (TAU / 8) * i
		var dir = Vector2.from_angle(angle)
		spark.rotation = angle

		var stween = TweenHelper.new_tween()
		stween.set_parallel(true)
		stween.tween_property(spark, "global_position", hit_pos + dir * 50, 0.10)
		stween.tween_property(spark, "modulate:a", 0.0, 0.12)
		stween.chain().tween_callback(spark.queue_free)

# Block attacks during flurry
func attack(direction: Vector2, player_damage_multiplier: float = 1.0) -> bool:
	if is_flurrying:
		return false
	return super.attack(direction, player_damage_multiplier)
