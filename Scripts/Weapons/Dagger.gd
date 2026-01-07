# SCRIPT: Dagger.gd
# ATTACH TO: Dagger (Node2D) root node in Dagger.tscn
# LOCATION: res://Scripts/Weapons/Dagger.gd
# Fast dagger with Shadow Strike skill

class_name Dagger
extends MeleeWeapon

# ============================================
# DAGGER-SPECIFIC STATE
# ============================================
var is_shadow_striking: bool = false
var _shadow_tween: Tween = null

# Shadow Strike settings
const SHADOW_DISTANCE: float = 200.0
const SHADOW_TIME: float = 0.1
const SHADOW_DAMAGE_MULTIPLIER: float = 2.5
const BACKSTAB_MULTIPLIER: float = 1.5  # Extra damage from behind

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
	attack_duration = 0.12  # Very fast
	attack_cooldown = 0.16  # Quick recovery
	swing_arc = 90.0  # Narrow arc
	weapon_length = 55.0  # Short reach
	weapon_color = DAGGER_BLADE_COLOR
	skill_cooldown = 5.0  # Short cooldown for mobility

	# Cone Hitbox - short range, focused
	attack_range = 110.0
	attack_cone_angle = 75.0

	# Attack Speed Limits (fast weapon)
	max_attacks_per_second = 5.5  # Very fast
	min_cooldown = 0.12

	# Idle - Dagger at the ready
	idle_rotation = 35.0
	idle_position = Vector2(4, -2)
	idle_scale = Vector2(0.55, 0.55)

	# Light knockback
	base_knockback = 150.0
	finisher_knockback = 300.0

	# Quick combos
	combo_window = 1.2
	combo_finisher_multiplier = 1.8
	combo_hits = 4  # 4-hit combo

	# Walk animation - light, swift
	walk_bob_amount = 4.0
	walk_sway_amount = 8.0
	walk_anim_speed = 1.5

	_setup_idle_state()

func _get_attack_pattern(attack_index: int) -> String:
	# Dagger: quick alternating stabs
	match attack_index:
		1: return "stab"
		2: return "horizontal"
		3: return "stab"
		4: return "horizontal_reverse"
		_: return "stab"

func _get_hit_color(combo_finisher: bool, dash_attack: bool, crit: bool) -> Color:
	if crit:
		return Color.RED
	elif combo_finisher:
		return DAGGER_GLOW_COLOR
	elif dash_attack or is_shadow_striking:
		return DAGGER_SHADOW_COLOR
	return DAGGER_BLADE_COLOR

func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	super._perform_attack_animation(pattern, duration, is_dash_attack)
	_create_dagger_slash_effect()

func _create_dagger_slash_effect():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Quick slash lines
	for i in range(2):
		var slash = ColorRect.new()
		slash.size = Vector2(weapon_length * 0.8, 4)
		slash.pivot_offset = Vector2(0, 2)
		scene.add_child(slash)
		slash.global_position = global_position + current_attack_direction * 15
		slash.rotation = current_attack_direction.angle() + (i - 0.5) * 0.15

		var mat = ShaderMaterial.new()
		mat.shader = shadow_shader
		mat.set_shader_parameter("trail_color", DAGGER_TRAIL_COLOR)
		mat.set_shader_parameter("glow_color", DAGGER_GLOW_COLOR)
		mat.set_shader_parameter("glow_intensity", 1.5)
		mat.set_shader_parameter("taper_amount", 0.8)
		mat.set_shader_parameter("progress", 0.0)
		slash.material = mat

		var tween = TweenHelper.new_tween()
		tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.08)
		tween.tween_callback(slash.queue_free)

func _on_combo_finisher_hit(_target: Node2D):
	DamageNumberManager.shake(0.2)
	_create_flurry_effect()

func _create_flurry_effect():
	if not player_reference:
		return

	var hit_pos = player_reference.global_position + current_attack_direction * 50
	var scene = get_tree().current_scene
	if not scene:
		return

	# Multiple quick slash marks
	for i in range(6):
		var slash = ColorRect.new()
		slash.size = Vector2(4, 30)
		slash.color = DAGGER_GLOW_COLOR
		slash.pivot_offset = Vector2(2, 15)
		scene.add_child(slash)
		slash.global_position = hit_pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		slash.rotation = randf() * TAU
		slash.scale = Vector2(0.3, 0.3)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(slash, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(slash, "modulate:a", 0.0, 0.15)
		tween.tween_callback(slash.queue_free)

# ============================================
# SHADOW STRIKE SKILL
# ============================================

func _is_async_skill() -> bool:
	return true

func _perform_skill() -> bool:
	if not player_reference:
		return false

	is_shadow_striking = true
	_execute_shadow_strike()
	return true

func _execute_shadow_strike():
	var player = player_reference
	if not is_instance_valid(player):
		is_shadow_striking = false
		_end_skill_invulnerability()
		return

	# Make player invulnerable
	player.is_invulnerable = true

	# Calculate direction toward mouse
	var direction = (player.get_global_mouse_position() - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	# Find nearest enemy in direction
	var target_pos = player.global_position + direction * SHADOW_DISTANCE
	var nearest_enemy = _find_nearest_enemy_in_direction(player.global_position, direction)

	if nearest_enemy and is_instance_valid(nearest_enemy):
		# Teleport behind enemy
		var behind_offset = (nearest_enemy.global_position - player.global_position).normalized()
		target_pos = nearest_enemy.global_position + behind_offset * 60

	# Create shadow effect at start position
	_create_shadow_vanish_effect(player.global_position)

	# Visual - fade out
	player.modulate = Color(0.3, 0.1, 0.4, 0.3)

	# Kill any existing tween
	if _shadow_tween and _shadow_tween.is_valid():
		_shadow_tween.kill()

	# Instant teleport with brief delay
	_shadow_tween = TweenHelper.new_tween()
	_shadow_tween.tween_interval(SHADOW_TIME)

	var dagger_ref = weakref(self)
	var player_ref = weakref(player)
	var enemy_ref = weakref(nearest_enemy) if nearest_enemy else null

	_shadow_tween.tween_callback(func():
		var d = dagger_ref.get_ref()
		var p = player_ref.get_ref()
		if d and p and is_instance_valid(p):
			p.global_position = target_pos
			d._create_shadow_appear_effect(target_pos)

			# Deal damage to nearby enemy
			var enemy = enemy_ref.get_ref() if enemy_ref else null
			if enemy and is_instance_valid(enemy) and enemy.has_method("take_damage"):
				var is_backstab = d._is_backstab(p, enemy)
				var final_damage = d.damage * d.damage_multiplier * SHADOW_DAMAGE_MULTIPLIER
				if is_backstab:
					final_damage *= BACKSTAB_MULTIPLIER
					d._create_backstab_text(enemy.global_position)
				enemy.take_damage(final_damage, p.global_position, 400.0, 0.2, p)
				d.dealt_damage.emit(enemy, final_damage)
	)

	_shadow_tween.tween_callback(func():
		var d = dagger_ref.get_ref()
		var p = player_ref.get_ref()
		if d:
			d._on_shadow_strike_finished(p)
	)

func _on_shadow_strike_finished(player: Node2D):
	if is_instance_valid(player):
		player.is_invulnerable = false
		player.modulate = Color.WHITE
	is_shadow_striking = false
	_shadow_tween = null
	_end_skill_invulnerability()

func _find_nearest_enemy_in_direction(origin: Vector2, direction: Vector2) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = SHADOW_DISTANCE * 1.5

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.is_in_group("converted_minion"):
			continue

		var to_enemy = enemy.global_position - origin
		var dist = to_enemy.length()

		# Check if enemy is roughly in the direction we're going
		var dot = to_enemy.normalized().dot(direction)
		if dot < 0.5:  # Must be within ~60 degrees
			continue

		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	return nearest

func _is_backstab(player: Node2D, enemy: Node2D) -> bool:
	if not is_instance_valid(enemy):
		return false

	# Check if player is behind enemy (based on enemy's facing direction)
	var enemy_facing = Vector2.RIGHT  # Default

	# Try to get enemy's facing direction
	if enemy.has_method("get_facing_direction"):
		enemy_facing = enemy.get_facing_direction()
	elif enemy.get("velocity") != null:
		var vel = enemy.velocity
		if vel.length() > 0:
			enemy_facing = vel.normalized()

	var to_player = (player.global_position - enemy.global_position).normalized()
	var dot = enemy_facing.dot(to_player)

	# Behind if dot product is negative (player is in opposite direction of facing)
	return dot < -0.3

func _create_shadow_vanish_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Dark smoke burst
	for i in range(8):
		var smoke = ColorRect.new()
		smoke.size = Vector2(20, 20)
		smoke.color = DAGGER_SHADOW_COLOR
		smoke.pivot_offset = Vector2(10, 10)
		scene.add_child(smoke)
		smoke.global_position = pos + Vector2(randf_range(-15, 15), randf_range(-15, 15))

		var angle = randf() * TAU
		var dir = Vector2.from_angle(angle)
		var end_pos = smoke.global_position + dir * randf_range(30, 60)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(smoke, "global_position", end_pos, 0.2)
		tween.tween_property(smoke, "scale", Vector2(2.0, 2.0), 0.2)
		tween.tween_property(smoke, "modulate:a", 0.0, 0.2)
		tween.tween_callback(smoke.queue_free)

func _create_shadow_appear_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Converging shadow particles
	for i in range(8):
		var angle = (TAU / 8) * i
		var start_pos = pos + Vector2.from_angle(angle) * 60

		var particle = ColorRect.new()
		particle.size = Vector2(12, 12)
		particle.color = DAGGER_GLOW_COLOR
		particle.pivot_offset = Vector2(6, 6)
		scene.add_child(particle)
		particle.global_position = start_pos

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", pos, 0.1)
		tween.tween_property(particle, "scale", Vector2(0.3, 0.3), 0.1)
		tween.tween_property(particle, "modulate:a", 0.0, 0.15)
		tween.tween_callback(particle.queue_free)

	# Flash at appear point
	var flash = ColorRect.new()
	flash.size = Vector2(40, 40)
	flash.color = DAGGER_GLOW_COLOR
	flash.pivot_offset = Vector2(20, 20)
	scene.add_child(flash)
	flash.global_position = pos - Vector2(20, 20)
	flash.scale = Vector2(0.5, 0.5)

	var flash_tween = TweenHelper.new_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(1.5, 1.5), 0.1)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.1)
	flash_tween.tween_callback(flash.queue_free)

func _create_backstab_text(spawn_pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	var label = Label.new()
	label.text = "BACKSTAB!"
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = DAGGER_GLOW_COLOR
	scene.add_child(label)
	label.global_position = spawn_pos + Vector2(-60, -100)

	var tween = TweenHelper.new_tween()
	tween.tween_property(label, "global_position:y", spawn_pos.y - 160, 0.4)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)

# Override attack to block during shadow strike
func attack(direction: Vector2, player_damage_multiplier: float = 1.0) -> bool:
	if is_shadow_striking:
		return false
	return super.attack(direction, player_damage_multiplier)
