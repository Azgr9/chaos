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

func _weapon_ready():
	# Warhammer: extremely slow but devastating
	damage = 35.0
	attack_duration = 0.6   # Very slow
	attack_cooldown = 0.8   # Long recovery
	swing_arc = 100.0       # Wide overhead arc
	weapon_length = 70.0    # Shorter, bulky
	weapon_color = Color(0.4, 0.35, 0.3)  # Dark iron
	idle_rotation = 60.0
	idle_scale = Vector2(0.7, 0.7)

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

	var impact_pos = player_reference.global_position + current_attack_direction * 70

	# Big screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.5)

	# Shockwave ring
	var ring = ColorRect.new()
	ring.size = Vector2(40, 40)
	ring.color = Color(0.5, 0.4, 0.3, 0.9)
	ring.pivot_offset = Vector2(20, 20)
	get_tree().current_scene.add_child(ring)
	ring.global_position = impact_pos - Vector2(20, 20)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(5, 5), 0.4)
	tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	tween.tween_callback(ring.queue_free)

	# Debris particles
	for i in range(8):
		var debris = ColorRect.new()
		debris.size = Vector2(16, 16)
		debris.color = Color(0.4, 0.35, 0.25, 0.9)
		get_tree().current_scene.add_child(debris)
		debris.global_position = impact_pos

		var angle = (TAU / 8) * i + randf_range(-0.3, 0.3)
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(60, 120)

		var dtween = TweenHelper.new_tween()
		dtween.set_parallel(true)
		dtween.tween_property(debris, "global_position", impact_pos + dir * dist, 0.3)
		dtween.tween_property(debris, "global_position:y", debris.global_position.y + 50, 0.3).set_delay(0.15)
		dtween.tween_property(debris, "modulate:a", 0.0, 0.3)
		dtween.tween_callback(debris.queue_free)

# ============================================
# EARTHQUAKE SKILL - AoE ground pound
# ============================================
func _perform_skill() -> bool:
	if not player_reference or is_earthquaking:
		return false

	is_earthquaking = true
	_execute_earthquake()
	return true

func _execute_earthquake():
	if not is_instance_valid(player_reference):
		is_earthquaking = false
		return

	# Jump up animation
	var original_pos = player_reference.global_position

	# Make player invulnerable during leap
	if player_reference.has_method("set_invulnerable"):
		player_reference.set_invulnerable(true)

	# Visual: hammer glows
	sprite.color = Color(1.0, 0.5, 0.0)
	sprite.scale = Vector2(1.5, 1.5)

	# Leap up
	var leap_tween = TweenHelper.new_tween()
	leap_tween.tween_property(player_reference, "global_position:y", original_pos.y - 100, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await leap_tween.finished

	# Check validity after await
	if not is_instance_valid(self) or not is_instance_valid(player_reference):
		is_earthquaking = false
		return

	# Slam down
	var slam_tween = TweenHelper.new_tween()
	slam_tween.tween_property(player_reference, "global_position:y", original_pos.y, 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await slam_tween.finished

	# Check validity after await
	if not is_instance_valid(self) or not is_instance_valid(player_reference):
		is_earthquaking = false
		return

	# End invulnerability
	if player_reference.has_method("set_invulnerable"):
		player_reference.set_invulnerable(false)

	# Earthquake impact!
	_earthquake_impact()

	# Reset
	sprite.color = weapon_color
	sprite.scale = idle_scale
	is_earthquaking = false

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

	var ring = ColorRect.new()
	ring.size = Vector2(50, 50)
	ring.color = Color(0.6, 0.4, 0.2, 0.8)
	ring.pivot_offset = Vector2(25, 25)
	get_tree().current_scene.add_child(ring)
	ring.global_position = pos - Vector2(25, 25)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(EARTHQUAKE_RADIUS / 25, EARTHQUAKE_RADIUS / 25), 0.4)
	tween.tween_property(ring, "modulate:a", 0.0, 0.4)
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
