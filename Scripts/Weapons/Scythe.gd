# SCRIPT: Scythe.gd
# ATTACH TO: Scythe (Node2D) root node in Scythe.tscn
# LOCATION: res://Scripts/Weapons/Scythe.gd
# Death's Scythe - Wide sweeping arc with lifesteal

class_name Scythe
extends MeleeWeapon

# ============================================
# SCYTHE-SPECIFIC SETTINGS
# ============================================

# Lifesteal
const LIFESTEAL_PERCENT: float = 0.15  # 15% of damage dealt
const FINISHER_LIFESTEAL_BONUS: float = 0.10  # Extra 10% on finisher

# Visual colors - Dark purple/black death theme
const SCYTHE_BLADE_COLOR: Color = Color(0.6, 0.2, 0.8)  # Purple blade
const SCYTHE_EDGE_COLOR: Color = Color(0.9, 0.3, 1.0)  # Bright purple edge
const SCYTHE_HANDLE_COLOR: Color = Color(0.15, 0.1, 0.2)  # Dark handle
const SCYTHE_SOUL_COLOR: Color = Color(0.4, 0.9, 0.5)  # Green soul energy
const SCYTHE_TRAIL_COLOR: Color = Color(0.5, 0.1, 0.6, 0.7)  # Dark purple trail

# Reap state
var souls_collected: int = 0
var is_reaping: bool = false

func _weapon_ready():
	# Scythe - wide arc, moderate damage, lifesteal focus
	damage = 18.0
	attack_duration = 0.38  # Medium-slow swing
	attack_cooldown = 0.5
	swing_arc = 180.0  # WIDE sweeping arc
	weapon_length = 100.0  # Long reach
	weapon_color = SCYTHE_BLADE_COLOR
	skill_cooldown = 10.0

	# Attack Speed Limits
	max_attacks_per_second = 2.5
	min_cooldown = 0.28

	# Idle appearance - scythe held at angle
	idle_rotation = 60.0
	idle_scale = Vector2(0.65, 0.65)

	# Moderate knockback (reaping motion)
	base_knockback = 350.0
	finisher_knockback = 600.0

	# Combo - reaping rhythm
	combo_finisher_multiplier = 1.7
	combo_window = 1.8
	combo_hits = 3

func _get_attack_pattern(attack_index: int) -> String:
	# Scythe: horizontal sweep -> reverse sweep -> soul reap (full circle)
	match attack_index:
		1: return "sweep"
		2: return "reverse_sweep"
		3: return "soul_reap"
		_: return "sweep"

func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	if active_attack_tween:
		active_attack_tween.kill()

	var is_finisher = is_combo_finisher()

	if sprite:
		if is_finisher:
			sprite.color = SCYTHE_SOUL_COLOR
		elif is_dash_attack:
			sprite.color = Color.CYAN

	match pattern:
		"sweep":
			_animate_sweep(duration, is_dash_attack, false)
		"reverse_sweep":
			_animate_sweep(duration, is_dash_attack, true)
		"soul_reap":
			_animate_soul_reap(duration, is_dash_attack)
		_:
			_animate_sweep(duration, is_dash_attack, false)

func _animate_sweep(duration: float, _is_dash_attack: bool, reverse: bool):
	active_attack_tween = TweenHelper.new_tween()

	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0
	var arc = swing_arc if not reverse else -swing_arc

	# Start from wide angle
	var start_angle = base_angle - arc * 0.6
	var end_angle = base_angle + arc * 0.4

	if pivot:
		pivot.rotation = deg_to_rad(start_angle)
		pivot.position = Vector2.ZERO
	if sprite:
		sprite.scale = Vector2(1.0, 1.0)

	# Brief wind-up
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(start_angle - (10 if not reverse else -10)), duration * 0.15)

	# Create soul wisps during windup
	active_attack_tween.tween_callback(_create_soul_wisps)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(is_combo_finisher(), false))

	# Sweeping arc - the main reaping motion
	active_attack_tween.tween_callback(_start_sweep_trail)
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(end_angle), duration * 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Follow through
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(end_angle + (15 if not reverse else -15)), duration * 0.25)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _animate_soul_reap(duration: float, _is_dash_attack: bool):
	# Finisher - Full 360 degree death spiral
	active_attack_tween = TweenHelper.new_tween()

	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	if pivot:
		pivot.rotation = deg_to_rad(base_angle)
		pivot.position = Vector2.ZERO
	if sprite:
		sprite.scale = Vector2(1.3, 1.3)
		sprite.color = SCYTHE_SOUL_COLOR

	# Soul gathering effect
	_create_soul_gathering_effect()

	# Brief charge
	active_attack_tween.tween_interval(duration * 0.1)

	# Enable hitbox for entire spin
	active_attack_tween.tween_callback(_enable_hitbox.bind(true, false))

	# Start intense trail
	active_attack_tween.tween_callback(_start_death_spiral_trail)

	# Full 360 spin - DEATH SPIRAL
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(base_angle + 360), duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# Souls explode outward
	active_attack_tween.tween_callback(_create_soul_explosion)

	# Recovery
	active_attack_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), duration * 0.2)
	active_attack_tween.tween_property(sprite, "color", weapon_color, duration * 0.2)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

# ============================================
# LIFESTEAL SYSTEM - Override _calculate_damage to apply lifesteal
# ============================================
func _calculate_damage(target: Node2D) -> float:
	var final_damage = super._calculate_damage(target)

	# Apply lifesteal after damage calculation
	var lifesteal_amount = final_damage * LIFESTEAL_PERCENT

	# Bonus lifesteal on finisher
	if is_combo_finisher():
		lifesteal_amount += final_damage * FINISHER_LIFESTEAL_BONUS

	# Delay lifesteal effect slightly so it happens after hit
	_apply_lifesteal_delayed(lifesteal_amount, target.global_position)

	return final_damage

func _apply_lifesteal_delayed(amount: float, from_pos: Vector2):
	# Use call_deferred to avoid issues during damage calculation
	call_deferred("_apply_lifesteal", amount, from_pos)

func _apply_lifesteal(amount: float, from_pos: Vector2):
	if not player_reference or not is_instance_valid(player_reference):
		return

	if player_reference.stats:
		player_reference.stats.heal(amount)
		player_reference.health_changed.emit(player_reference.stats.current_health, player_reference.stats.max_health)

	# Visual feedback - soul flowing to player
	_create_soul_steal_effect(from_pos)

	# Heal number
	if DamageNumberManager:
		DamageNumberManager.spawn(player_reference.global_position, amount, DamageTypes.Type.HEAL)

	souls_collected += 1

func _create_soul_steal_effect(from_pos: Vector2):
	if not player_reference:
		return

	# Soul orb travels from enemy to player
	var soul = ColorRect.new()
	soul.size = Vector2(12, 12)
	soul.color = SCYTHE_SOUL_COLOR
	soul.pivot_offset = Vector2(6, 6)

	var scene = get_tree().current_scene
	if not scene:
		return
	scene.add_child(soul)
	soul.global_position = from_pos

	# Curved path to player
	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)

	# Arc upward then to player
	var mid_point = from_pos + Vector2(0, -50) + (player_reference.global_position - from_pos) * 0.5

	tween.tween_property(soul, "global_position", mid_point, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(soul, "global_position", player_reference.global_position, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.tween_property(soul, "scale", Vector2(0.5, 0.5), 0.3)
	tween.tween_property(soul, "modulate:a", 0.0, 0.3).set_delay(0.2)
	tween.chain().tween_callback(soul.queue_free)

# ============================================
# VISUAL EFFECTS
# ============================================
func _create_soul_wisps():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	for i in range(3):
		var wisp = ColorRect.new()
		wisp.size = Vector2(6, 6)
		wisp.color = Color(SCYTHE_SOUL_COLOR.r, SCYTHE_SOUL_COLOR.g, SCYTHE_SOUL_COLOR.b, 0.6)
		wisp.pivot_offset = Vector2(3, 3)
		scene.add_child(wisp)

		var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		wisp.global_position = global_position + offset

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(wisp, "global_position", global_position, 0.2)
		tween.tween_property(wisp, "modulate:a", 0.0, 0.2)
		tween.tween_property(wisp, "scale", Vector2(0.3, 0.3), 0.2)
		tween.tween_callback(wisp.queue_free)

func _start_sweep_trail():
	_create_scythe_trail(5)

func _start_death_spiral_trail():
	_create_scythe_trail(12)

func _create_scythe_trail(count: int):
	if not player_reference:
		return

	for i in range(count):
		_spawn_delayed_trail_segment(i * 0.03)

func _spawn_delayed_trail_segment(delay: float):
	await get_tree().create_timer(delay).timeout

	if not is_instance_valid(self):
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	var trail = ColorRect.new()
	trail.size = Vector2(8, weapon_length * 0.8)
	trail.color = SCYTHE_TRAIL_COLOR
	trail.pivot_offset = Vector2(4, weapon_length * 0.4)
	scene.add_child(trail)
	trail.global_position = global_position
	trail.rotation = pivot.rotation

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "modulate:a", 0.0, 0.15)
	tween.tween_property(trail, "scale:x", 0.2, 0.15)
	tween.tween_callback(trail.queue_free)

func _create_soul_gathering_effect():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Souls spiral inward
	for i in range(8):
		var soul = ColorRect.new()
		soul.size = Vector2(10, 10)
		soul.color = SCYTHE_SOUL_COLOR
		soul.pivot_offset = Vector2(5, 5)
		scene.add_child(soul)

		var angle = (TAU / 8) * i
		var start_pos = player_reference.global_position + Vector2.from_angle(angle) * 100
		soul.global_position = start_pos
		soul.scale = Vector2(0.5, 0.5)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(soul, "global_position", player_reference.global_position, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(soul, "scale", Vector2(1.5, 1.5), 0.15)
		tween.chain().tween_property(soul, "scale", Vector2(0.3, 0.3), 0.15)
		tween.tween_property(soul, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(soul.queue_free)

func _create_soul_explosion():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Souls burst outward
	for i in range(12):
		var soul = ColorRect.new()
		soul.size = Vector2(8, 8)
		soul.color = SCYTHE_SOUL_COLOR
		soul.pivot_offset = Vector2(4, 4)
		scene.add_child(soul)
		soul.global_position = player_reference.global_position

		var angle = (TAU / 12) * i + randf_range(-0.2, 0.2)
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(80, 140)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(soul, "global_position", player_reference.global_position + dir * dist, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(soul, "rotation", randf_range(-TAU, TAU), 0.3)
		tween.tween_property(soul, "modulate:a", 0.0, 0.3)
		tween.tween_callback(soul.queue_free)

	# Screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.35)

# ============================================
# SKILL - DEATH SPIRAL (Kite-style Spinning Cleave)
# ============================================
const SPIN_RADIUS: float = 180.0  # Large cleave area
const SPIN_DAMAGE_MULT: float = 2.0  # 2x damage
const SPIN_DURATION: float = 1.2  # Total spin duration
const SPIN_ROTATIONS: int = 3  # Number of full rotations
const SPIN_HIT_INTERVAL: float = 0.15  # Damage tick interval

var is_spinning: bool = false
var spin_hit_enemies: Dictionary = {}  # Track hit cooldowns per enemy

func _perform_skill() -> bool:
	if not player_reference or is_spinning:
		return false

	is_spinning = true
	_execute_death_spiral()
	return true

func _is_async_skill() -> bool:
	return true  # Uses await

func _execute_death_spiral():
	var player = player_reference
	if not is_instance_valid(player):
		is_spinning = false
		_end_skill_invulnerability()
		return

	spin_hit_enemies.clear()

	# Lock player movement during spin
	if player.has_method("set_movement_locked"):
		player.set_movement_locked(true)

	# Visual setup - scythe grows larger
	if sprite:
		sprite.color = SCYTHE_SOUL_COLOR
		sprite.scale = Vector2(1.8, 1.8)

	# Create spinning visual effects
	_create_spin_start_effect()

	# Make scythe visible and extended
	if pivot:
		pivot.position = Vector2.ZERO

	# Screen shake start
	if DamageNumberManager:
		DamageNumberManager.shake(0.3)

	# Spinning damage loop
	_spin_damage_loop()

	# Main spin animation - 3 full rotations
	var start_rotation = pivot.rotation if pivot else 0.0
	var total_rotation = TAU * SPIN_ROTATIONS

	var spin_tween = TweenHelper.new_tween()
	spin_tween.tween_property(pivot, "rotation", start_rotation + total_rotation, SPIN_DURATION)\
		.set_trans(Tween.TRANS_LINEAR)

	# Create trail during entire spin
	_create_spin_trail()

	await spin_tween.finished

	if not is_instance_valid(self) or not is_instance_valid(player):
		is_spinning = false
		_end_skill_invulnerability()
		return

	# Final burst effect
	_create_spin_end_effect()

	# Reset weapon state
	if sprite:
		var reset_tween = TweenHelper.new_tween()
		reset_tween.set_parallel(true)
		reset_tween.tween_property(sprite, "scale", idle_scale, 0.2)
		reset_tween.tween_property(sprite, "color", weapon_color, 0.2)

	# Unlock player movement
	if player.has_method("set_movement_locked"):
		player.set_movement_locked(false)

	is_spinning = false
	spin_hit_enemies.clear()
	_end_skill_invulnerability()

func _spin_damage_loop():
	var elapsed: float = 0.0

	while elapsed < SPIN_DURATION and is_spinning and is_instance_valid(self):
		await get_tree().create_timer(SPIN_HIT_INTERVAL).timeout

		if not is_instance_valid(self) or not is_spinning:
			return

		elapsed += SPIN_HIT_INTERVAL

		# Find and damage enemies in radius
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue

			var dist = enemy.global_position.distance_to(player_reference.global_position)
			if dist > SPIN_RADIUS:
				continue

			# Check hit cooldown for this enemy
			var enemy_id = enemy.get_instance_id()
			if spin_hit_enemies.has(enemy_id):
				spin_hit_enemies[enemy_id] -= SPIN_HIT_INTERVAL
				if spin_hit_enemies[enemy_id] > 0:
					continue

			# Hit this enemy
			spin_hit_enemies[enemy_id] = 0.3  # Cooldown before hitting same enemy again

			var spin_damage = damage * SPIN_DAMAGE_MULT * damage_multiplier
			if enemy.has_method("take_damage"):
				enemy.take_damage(spin_damage, player_reference.global_position, 200.0, 0.1, player_reference)
				dealt_damage.emit(enemy, spin_damage)

			# Lifesteal on spin hits
			var heal_amount = spin_damage * LIFESTEAL_PERCENT
			_apply_lifesteal(heal_amount, enemy.global_position)

			# Hit effect
			_create_spin_hit_effect(enemy.global_position)

func _create_spin_start_effect():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Dark energy gathering
	for i in range(12):
		var soul = ColorRect.new()
		soul.size = Vector2(10, 10)
		soul.color = SCYTHE_SOUL_COLOR
		soul.pivot_offset = Vector2(5, 5)
		scene.add_child(soul)

		var angle = (TAU / 12) * i
		soul.global_position = player_reference.global_position + Vector2.from_angle(angle) * SPIN_RADIUS

		var tween = TweenHelper.new_tween()
		tween.tween_property(soul, "global_position", player_reference.global_position, 0.25)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(soul, "modulate:a", 0.0, 0.1)
		tween.tween_callback(soul.queue_free)

	# Ground circle indicator
	var circle = ColorRect.new()
	circle.size = Vector2(SPIN_RADIUS * 2, SPIN_RADIUS * 2)
	circle.color = Color(SCYTHE_EDGE_COLOR.r, SCYTHE_EDGE_COLOR.g, SCYTHE_EDGE_COLOR.b, 0.2)
	circle.pivot_offset = Vector2(SPIN_RADIUS, SPIN_RADIUS)
	scene.add_child(circle)
	circle.global_position = player_reference.global_position - Vector2(SPIN_RADIUS, SPIN_RADIUS)
	circle.scale = Vector2(0.2, 0.2)

	var c_tween = TweenHelper.new_tween()
	c_tween.tween_property(circle, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	c_tween.tween_interval(SPIN_DURATION - 0.3)
	c_tween.tween_property(circle, "modulate:a", 0.0, 0.2)
	c_tween.tween_callback(circle.queue_free)

func _create_spin_trail():
	var trail_segments: int = int(SPIN_DURATION * 20)  # 20 segments per second

	for i in range(trail_segments):
		_spawn_spin_trail_segment(i * (SPIN_DURATION / trail_segments))

func _spawn_spin_trail_segment(delay: float):
	await get_tree().create_timer(delay).timeout

	if not is_instance_valid(self) or not is_spinning or not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Arc trail segment
	var trail = ColorRect.new()
	trail.size = Vector2(10, weapon_length * 1.5)
	trail.color = Color(SCYTHE_TRAIL_COLOR.r, SCYTHE_TRAIL_COLOR.g, SCYTHE_TRAIL_COLOR.b, 0.8)
	trail.pivot_offset = Vector2(5, 0)
	scene.add_child(trail)
	trail.global_position = player_reference.global_position
	trail.rotation = pivot.rotation if pivot else 0.0

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "modulate:a", 0.0, 0.12)
	tween.tween_property(trail, "scale:x", 0.2, 0.12)
	tween.tween_callback(trail.queue_free)

func _create_spin_hit_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Purple slash marks
	for i in range(3):
		var slash = ColorRect.new()
		slash.size = Vector2(4, 25)
		slash.color = SCYTHE_EDGE_COLOR
		slash.pivot_offset = Vector2(2, 12.5)
		scene.add_child(slash)
		slash.global_position = pos
		slash.rotation = randf_range(0, TAU)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(slash, "scale", Vector2(1.5, 1.5), 0.08)
		tween.tween_property(slash, "modulate:a", 0.0, 0.12)
		tween.tween_callback(slash.queue_free)

func _create_spin_end_effect():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Massive soul explosion
	for i in range(16):
		var soul = ColorRect.new()
		soul.size = Vector2(12, 12)
		soul.color = SCYTHE_SOUL_COLOR
		soul.pivot_offset = Vector2(6, 6)
		scene.add_child(soul)
		soul.global_position = player_reference.global_position

		var angle = (TAU / 16) * i
		var dir = Vector2.from_angle(angle)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(soul, "global_position", player_reference.global_position + dir * SPIN_RADIUS * 1.2, 0.3)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(soul, "rotation", randf_range(-TAU, TAU), 0.3)
		tween.tween_property(soul, "modulate:a", 0.0, 0.3)
		tween.tween_callback(soul.queue_free)

	# Final shockwave
	var shockwave = ColorRect.new()
	shockwave.size = Vector2(60, 60)
	shockwave.color = Color(SCYTHE_EDGE_COLOR.r, SCYTHE_EDGE_COLOR.g, SCYTHE_EDGE_COLOR.b, 0.6)
	shockwave.pivot_offset = Vector2(30, 30)
	scene.add_child(shockwave)
	shockwave.global_position = player_reference.global_position - Vector2(30, 30)

	var s_tween = TweenHelper.new_tween()
	s_tween.set_parallel(true)
	s_tween.tween_property(shockwave, "scale", Vector2(SPIN_RADIUS / 30.0, SPIN_RADIUS / 30.0), 0.25)
	s_tween.tween_property(shockwave, "modulate:a", 0.0, 0.25)
	s_tween.tween_callback(shockwave.queue_free)

	# Big screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.5)

func _on_combo_finisher_hit(_target: Node2D):
	if DamageNumberManager:
		DamageNumberManager.shake(0.3)
	_create_soul_explosion()

func _get_hit_color(combo_finisher: bool, dash_attack: bool, crit: bool) -> Color:
	if crit:
		return SCYTHE_SOUL_COLOR
	elif combo_finisher:
		return Color.GOLD
	elif dash_attack:
		return Color.CYAN
	return SCYTHE_EDGE_COLOR
