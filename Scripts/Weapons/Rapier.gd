# SCRIPT: Rapier.gd
# ATTACH TO: Rapier (Node2D) root node in Rapier.tscn
# LOCATION: res://Scripts/Weapons/Rapier.gd
# Fast, precise thrusting weapon with Flurry skill

class_name Rapier
extends MeleeWeapon

# ============================================
# RAPIER-SPECIFIC STATE
# ============================================
var is_flurrying: bool = false
const FLURRY_STABS: int = 6  # More stabs for better feel
const FLURRY_INTERVAL: float = 0.07  # Faster flurry
const FLURRY_DAMAGE_MULTIPLIER: float = 0.55

# Visual colors
const RAPIER_BLADE_COLOR: Color = Color(0.9, 0.9, 0.95)  # Polished silver
const RAPIER_THRUST_COLOR: Color = Color(0.6, 0.8, 1.0, 0.8)  # Light blue thrust
const RAPIER_SPARK_COLOR: Color = Color(1.0, 1.0, 1.0)  # White sparks

func _weapon_ready():
	# Rapier - fastest weapon, precision-focused
	damage = 8.0
	attack_duration = 0.14  # Very fast attacks
	attack_cooldown = 0.20  # Quick recovery
	swing_arc = 30.0        # Narrow arc (mostly stabs)
	weapon_length = 100.0   # Longest reach of melee weapons
	weapon_color = RAPIER_BLADE_COLOR
	idle_rotation = 30.0
	idle_scale = Vector2(0.5, 0.8)

	# Combo settings - fastest combo, 4-hit
	combo_window = 1.2  # Slightly wider window for usability
	combo_finisher_multiplier = 2.0  # Big payoff for completing combo
	combo_hits = 4

	# Lower knockback (precision weapon)
	base_knockback = 150.0
	finisher_knockback = 350.0

	# Skill settings
	skill_cooldown = 5.0

func _get_attack_pattern(attack_index: int) -> String:
	# Rapier: stab -> stab -> slash -> lunge
	match attack_index:
		1: return "stab"
		2: return "stab"
		3: return "horizontal"
		4: return "lunge"
		_: return "stab"

func _get_hit_color(combo_finisher: bool, dash_attack: bool, crit: bool) -> Color:
	if crit:
		return Color.RED
	elif combo_finisher:
		return Color.GOLD
	elif dash_attack or is_flurrying:
		return RAPIER_THRUST_COLOR
	return RAPIER_BLADE_COLOR

# ============================================
# LUNGE ATTACK (4th hit finisher)
# ============================================
func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	if pattern == "lunge":
		_animate_lunge(duration, is_dash_attack)
	elif pattern == "stab":
		_animate_rapier_stab(duration, is_dash_attack)
	else:
		super._perform_attack_animation(pattern, duration, is_dash_attack)

# ============================================
# RAPIER STAB - Extended reach thrust
# ============================================
func _animate_rapier_stab(duration: float, _is_dash_attack: bool):
	if active_attack_tween:
		active_attack_tween.kill()

	active_attack_tween = create_tween()

	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	# Point at target
	pivot.rotation = deg_to_rad(base_angle)
	pivot.position = Vector2.ZERO
	sprite.scale = Vector2(0.9, 1.1)  # Slight elongation for thrust feel
	sprite.color = RAPIER_BLADE_COLOR

	# Quick pullback
	var pullback_pos = current_attack_direction * -25
	active_attack_tween.tween_property(pivot, "position", pullback_pos, duration * 0.12)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(is_combo_finisher(), false))

	# Long thrust forward - rapier has the longest reach
	var thrust_distance = 110.0 if is_combo_finisher() else 90.0
	var thrust_pos = current_attack_direction * thrust_distance
	active_attack_tween.tween_property(pivot, "position", thrust_pos, duration * 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Create thrust trail effect
	active_attack_tween.tween_callback(_create_thrust_trail)

	# Quick return
	active_attack_tween.tween_property(pivot, "position", Vector2.ZERO, duration * 0.25)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _create_thrust_trail():
	if not player_reference:
		return

	# Create a sharp thrust line effect
	var trail = ColorRect.new()
	trail.size = Vector2(3, 70)
	trail.color = RAPIER_THRUST_COLOR
	trail.pivot_offset = Vector2(1.5, 35)
	get_tree().current_scene.add_child(trail)
	trail.global_position = global_position + current_attack_direction * 50
	trail.rotation = current_attack_direction.angle() + PI/2

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "scale:y", 1.5, 0.08)
	tween.tween_property(trail, "modulate:a", 0.0, 0.12)
	tween.tween_callback(trail.queue_free)

func _animate_lunge(duration: float, _is_dash_attack: bool):
	if active_attack_tween:
		active_attack_tween.kill()

	active_attack_tween = create_tween()

	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	# Point at target
	pivot.rotation = deg_to_rad(base_angle)
	pivot.position = Vector2.ZERO
	sprite.scale = Vector2(1.2, 1.2)
	sprite.color = Color.GOLD

	# Pull back
	var pullback_pos = current_attack_direction * -40
	active_attack_tween.tween_property(pivot, "position", pullback_pos, duration * 0.2)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(true, false))

	# Powerful lunge forward - extended rapier reach
	var lunge_distance = 140.0
	var lunge_pos = current_attack_direction * lunge_distance
	active_attack_tween.tween_property(pivot, "position", lunge_pos, duration * 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Move player forward slightly
	if player_reference:
		var player_move = player_reference.global_position + current_attack_direction * 60
		active_attack_tween.parallel().tween_property(player_reference, "global_position", player_move, duration * 0.3)

	# Hold briefly
	active_attack_tween.tween_interval(duration * 0.15)

	# Return
	active_attack_tween.tween_property(pivot, "position", Vector2.ZERO, duration * 0.2)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

# ============================================
# FLURRY SKILL - Rapid multi-stab
# ============================================
func _perform_skill() -> bool:
	if not player_reference or is_flurrying:
		return false

	is_flurrying = true
	_execute_flurry()
	return true

func _execute_flurry():
	var direction = (player_reference.get_global_mouse_position() - player_reference.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	# Visual: rapier glows during flurry
	sprite.color = Color(0.6, 0.8, 1.0)

	for i in range(FLURRY_STABS):
		if not is_instance_valid(self) or not is_instance_valid(player_reference):
			break

		_perform_flurry_stab(direction, i)
		await get_tree().create_timer(FLURRY_INTERVAL).timeout

		# Re-check validity after await
		if not is_instance_valid(self) or not is_instance_valid(player_reference):
			return

	is_flurrying = false
	if is_instance_valid(self):
		sprite.color = weapon_color

func _perform_flurry_stab(direction: Vector2, stab_index: int):
	if not is_instance_valid(player_reference):
		return

	# Slight angle variation for visual interest
	var angle_offset = sin(stab_index * 1.5) * 15.0
	var stab_direction = direction.rotated(deg_to_rad(angle_offset))

	# Quick stab animation
	var base_angle = rad_to_deg(stab_direction.angle()) + 90.0
	pivot.rotation = deg_to_rad(base_angle)

	# Stab motion - extended reach for rapier
	var tween = create_tween()
	tween.tween_property(pivot, "position", stab_direction * 100, FLURRY_INTERVAL * 0.4)
	tween.tween_property(pivot, "position", Vector2.ZERO, FLURRY_INTERVAL * 0.4)

	# Deal damage to enemies in front
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not is_instance_valid(player_reference):
			continue

		var to_enemy = enemy.global_position - player_reference.global_position
		var distance = to_enemy.length()

		if distance < 140.0:  # Extended range check for rapier
			var dot = to_enemy.normalized().dot(direction)
			if dot > 0.5:  # Cone check
				var flurry_damage = damage * damage_multiplier * FLURRY_DAMAGE_MULTIPLIER
				if enemy.has_method("take_damage"):
					enemy.take_damage(flurry_damage, player_reference.global_position, 100.0, 0.05, player_reference)
					dealt_damage.emit(enemy, flurry_damage)
					_create_stab_effect(enemy.global_position)

func _create_stab_effect(pos: Vector2):
	var particle = ColorRect.new()
	particle.size = Vector2(8, 20)
	particle.color = Color(0.7, 0.8, 1.0, 0.8)
	particle.pivot_offset = Vector2(4, 10)
	get_tree().current_scene.add_child(particle)
	particle.global_position = pos

	var angle = randf_range(-0.3, 0.3)
	particle.rotation = angle

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(particle, "global_position:y", pos.y - 30, 0.15)
	tween.tween_property(particle, "modulate:a", 0.0, 0.15)
	tween.tween_callback(particle.queue_free)

func _on_combo_finisher_hit(target: Node2D):
	# Precision strike - small screen effect and thrust line
	DamageNumberManager.shake(0.2)
	_create_precision_thrust_effect(target.global_position if is_instance_valid(target) else player_reference.global_position + current_attack_direction * 60)

func _create_precision_thrust_effect(hit_pos: Vector2):
	# Sharp thrust line
	var thrust_line = ColorRect.new()
	thrust_line.size = Vector2(4, 100)
	thrust_line.color = RAPIER_SPARK_COLOR
	thrust_line.pivot_offset = Vector2(2, 50)
	get_tree().current_scene.add_child(thrust_line)
	thrust_line.global_position = hit_pos
	thrust_line.rotation = current_attack_direction.angle() + PI/2

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(thrust_line, "scale:y", 1.5, 0.1)
	tween.tween_property(thrust_line, "modulate:a", 0.0, 0.15)
	tween.tween_callback(thrust_line.queue_free)

	# Spark burst at hit point
	for i in range(6):
		var spark = ColorRect.new()
		spark.size = Vector2(3, 10)
		spark.color = RAPIER_SPARK_COLOR
		spark.pivot_offset = Vector2(1.5, 5)
		get_tree().current_scene.add_child(spark)
		spark.global_position = hit_pos

		var angle = (TAU / 6) * i + randf_range(-0.2, 0.2)
		var dir = Vector2.from_angle(angle)

		var stween = create_tween()
		stween.set_parallel(true)
		stween.tween_property(spark, "global_position", hit_pos + dir * 40, 0.12)
		stween.tween_property(spark, "modulate:a", 0.0, 0.12)
		stween.tween_callback(spark.queue_free)

# Block attacks during flurry
func attack(direction: Vector2, player_damage_multiplier: float = 1.0) -> bool:
	if is_flurrying:
		return false
	return super.attack(direction, player_damage_multiplier)
