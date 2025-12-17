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
const FLURRY_STABS: int = 5
const FLURRY_INTERVAL: float = 0.08
const FLURRY_DAMAGE_MULTIPLIER: float = 0.6

func _weapon_ready():
	# Rapier: fast, precise, low damage per hit
	damage = 8.0
	attack_duration = 0.15  # Very fast
	attack_cooldown = 0.2   # Quick recovery
	swing_arc = 30.0        # Narrow arc (mostly stabs)
	weapon_length = 90.0    # Long reach
	weapon_color = Color(0.8, 0.8, 0.9)  # Silver
	idle_rotation = 30.0
	idle_scale = Vector2(0.5, 0.7)

	# Combo settings - fast combo
	combo_window = 1.2
	combo_finisher_multiplier = 1.8
	combo_hits = 4  # 4-hit combo

	# Lower knockback (precision weapon)
	base_knockback = 200.0
	finisher_knockback = 400.0

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
		return Color(0.6, 0.8, 1.0)  # Light blue for rapier
	return weapon_color

# ============================================
# LUNGE ATTACK (4th hit finisher)
# ============================================
func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	if pattern == "lunge":
		_animate_lunge(duration, is_dash_attack)
	else:
		super._perform_attack_animation(pattern, duration, is_dash_attack)

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

	# Powerful lunge forward
	var lunge_distance = 120.0
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

	is_flurrying = false
	sprite.color = weapon_color

func _perform_flurry_stab(direction: Vector2, stab_index: int):
	# Slight angle variation for visual interest
	var angle_offset = sin(stab_index * 1.5) * 15.0
	var stab_direction = direction.rotated(deg_to_rad(angle_offset))

	# Quick stab animation
	var base_angle = rad_to_deg(stab_direction.angle()) + 90.0
	pivot.rotation = deg_to_rad(base_angle)

	# Stab motion
	var tween = create_tween()
	tween.tween_property(pivot, "position", stab_direction * 80, FLURRY_INTERVAL * 0.4)
	tween.tween_property(pivot, "position", Vector2.ZERO, FLURRY_INTERVAL * 0.4)

	# Deal damage to enemies in front
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var to_enemy = enemy.global_position - player_reference.global_position
		var distance = to_enemy.length()

		if distance < 120.0:  # Range check
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

func _on_combo_finisher_hit(_target: Node2D):
	# Precision strike - small screen effect
	DamageNumberManager.shake(0.2)

# Block attacks during flurry
func attack(direction: Vector2, player_damage_multiplier: float = 1.0) -> bool:
	if is_flurrying:
		return false
	return super.attack(direction, player_damage_multiplier)
