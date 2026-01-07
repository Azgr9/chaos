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

# Shader references
var shockwave_shader: Shader = preload("res://Shaders/Weapons/ImpactShockwave.gdshader")
var crack_shader: Shader = preload("res://Shaders/Weapons/GroundCrack.gdshader")
var energy_shader: Shader = preload("res://Shaders/Weapons/EnergyGlow.gdshader")

# Colors
const HAMMER_GLOW_COLOR: Color = Color(1.0, 0.5, 0.1)  # Orange impact
const HAMMER_EARTH_COLOR: Color = Color(0.5, 0.4, 0.25)  # Earth brown
const WARHAMMER_HEAD_COLOR: Color = Color(0.4, 0.35, 0.3)  # Dark iron hammer head

func _weapon_ready():
	# Warhammer: extremely slow but devastating
	damage = 35.0
	attack_duration = 0.6   # Very slow
	attack_cooldown = 0.8   # Long recovery
	swing_arc = 100.0       # Wide overhead arc
	weapon_length = 70.0    # Shorter, bulky
	weapon_color = Color(0.4, 0.35, 0.3)  # Dark iron

	# Idle appearance - Hammer resting on ground, leaning against player
	idle_rotation = 80.0  # Almost vertical, leaning
	idle_position = Vector2(8, 10)  # Down and to the side (grounded)
	idle_scale = Vector2(0.7, 0.7)

	# Cone Hitbox - Now configured via @export in scene inspector
	# attack_range = 110.0  # Medium range for smash
	# attack_cone_angle = 120.0  # Very wide crushing arc

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

	# Walk animation - heaviest weapon = very slow, heavy bob
	walk_bob_amount = 14.0  # Massive bob for heaviest weapon
	walk_sway_amount = 20.0  # Heavy sway
	walk_anim_speed = 0.5  # Slowest animation

	# Apply idle state after setting custom values
	_setup_idle_state()

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

	var scene = get_tree().current_scene
	if not scene:
		return

	var impact_pos = player_reference.global_position + current_attack_direction * 70

	# Big screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.5)

	# Shader-based shockwave
	var ring = ColorRect.new()
	ring.size = Vector2(200, 200)
	ring.pivot_offset = Vector2(100, 100)
	ring.global_position = impact_pos - Vector2(100, 100)

	var mat = ShaderMaterial.new()
	mat.shader = shockwave_shader
	mat.set_shader_parameter("wave_color", HAMMER_GLOW_COLOR)
	mat.set_shader_parameter("ring_thickness", 0.15)
	mat.set_shader_parameter("inner_glow", 1.8)
	mat.set_shader_parameter("progress", 0.0)
	ring.material = mat

	scene.add_child(ring)

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.4)
	tween.tween_callback(ring.queue_free)

	# Shader-based ground cracks
	for i in range(8):
		var crack = ColorRect.new()
		crack.size = Vector2(randf_range(70, 110), 8)
		crack.pivot_offset = Vector2(0, 4)
		crack.rotation = (TAU / 8) * i + randf_range(-0.2, 0.2)
		crack.global_position = impact_pos

		var crack_mat = ShaderMaterial.new()
		crack_mat.shader = crack_shader
		crack_mat.set_shader_parameter("crack_color", HAMMER_EARTH_COLOR)
		crack_mat.set_shader_parameter("glow_color", HAMMER_GLOW_COLOR)
		crack_mat.set_shader_parameter("progress", 0.0)
		crack.material = crack_mat

		scene.add_child(crack)

		var crack_tween = TweenHelper.new_tween()
		crack_tween.tween_method(func(p): crack_mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.5)
		crack_tween.tween_callback(crack.queue_free)

	# Debris particles
	for i in range(10):
		var debris = ColorRect.new()
		debris.size = Vector2(randf_range(12, 20), randf_range(12, 20))
		debris.color = Color(0.45, 0.38, 0.28, 1.0)
		debris.pivot_offset = debris.size / 2
		scene.add_child(debris)
		debris.global_position = impact_pos

		var angle = (TAU / 10) * i + randf_range(-0.25, 0.25)
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(70, 140)

		var dtween = TweenHelper.new_tween()
		dtween.set_parallel(true)
		dtween.tween_property(debris, "global_position", impact_pos + dir * dist, 0.35)
		dtween.tween_property(debris, "global_position:y", debris.global_position.y + 60, 0.35).set_delay(0.18)
		dtween.tween_property(debris, "rotation", randf_range(-TAU, TAU), 0.35)
		dtween.tween_property(debris, "modulate:a", 0.0, 0.35)
		dtween.tween_callback(debris.queue_free)

# ============================================
# MJOLNIR STRIKE - Throw hammer to sky, returns with lightning
# ============================================
const MJOLNIR_RADIUS: float = 300.0
const MJOLNIR_DAMAGE_MULT: float = 4.0
const LIGHTNING_CHAINS: int = 3

## This is an async skill - it uses await and manages its own invulnerability
func _is_async_skill() -> bool:
	return true

func _perform_skill() -> bool:
	if not player_reference or is_earthquaking:
		return false

	is_earthquaking = true
	_execute_mjolnir_strike()
	return true

func _execute_mjolnir_strike():
	if not is_instance_valid(player_reference):
		is_earthquaking = false
		_end_skill_invulnerability()
		return

	var player = player_reference
	var target_pos = player.get_global_mouse_position()

	# Show skill text
	_create_mjolnir_text(player.global_position)

	# Hide weapon - it's being thrown!
	visible = false

	# Create flying hammer visual
	_create_flying_hammer(player.global_position, target_pos)

	# Player reaches up pose
	player.modulate = Color(0.8, 0.9, 1.0)

	# Wait for hammer to fly up and come down
	await get_tree().create_timer(0.8).timeout

	if not is_instance_valid(self) or not is_instance_valid(player):
		visible = true
		is_earthquaking = false
		_end_skill_invulnerability()
		return

	# LIGHTNING STRIKE!
	_create_lightning_strike(target_pos)

	# Massive screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(1.0)

	# Damage enemies at impact
	_mjolnir_impact(target_pos, player)

	# Chain lightning to nearby enemies
	_chain_lightning(target_pos, player)

	# Show weapon again
	visible = true
	player.modulate = Color.WHITE

	# Brief recovery
	await get_tree().create_timer(0.3).timeout

	is_earthquaking = false
	_end_skill_invulnerability()

func _create_mjolnir_text(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	var label = Label.new()
	label.text = "MJOLNIR STRIKE!"
	label.add_theme_font_size_override("font_size", 32)
	label.modulate = Color(0.5, 0.7, 1.0)
	scene.add_child(label)
	label.global_position = pos + Vector2(-120, -80)

	var tween = TweenHelper.new_tween()
	tween.tween_property(label, "global_position:y", pos.y - 140, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)

func _create_flying_hammer(start_pos: Vector2, target_pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Create hammer visual
	var hammer = ColorRect.new()
	hammer.size = Vector2(25, 50)
	hammer.color = WARHAMMER_HEAD_COLOR
	hammer.pivot_offset = Vector2(12.5, 25)
	scene.add_child(hammer)
	hammer.global_position = start_pos - Vector2(12.5, 25)
	hammer.z_index = 100

	# Hammer glow
	var glow = ColorRect.new()
	glow.size = Vector2(40, 60)
	glow.color = Color(0.5, 0.7, 1.0, 0.5)
	glow.pivot_offset = Vector2(20, 30)
	glow.position = Vector2(-7.5, -5)
	glow.z_index = -1
	hammer.add_child(glow)

	# Fly up off screen
	var sky_pos = start_pos + Vector2(0, -600)

	var up_tween = TweenHelper.new_tween()
	up_tween.set_parallel(true)
	up_tween.tween_property(hammer, "global_position", sky_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up_tween.tween_property(hammer, "rotation", TAU * 2, 0.3)
	up_tween.tween_property(hammer, "scale", Vector2(0.5, 0.5), 0.3)

	await up_tween.finished

	if not is_instance_valid(hammer):
		return

	# Brief pause in "sky"
	await get_tree().create_timer(0.2).timeout

	if not is_instance_valid(hammer):
		return

	# CRASH DOWN with lightning!
	hammer.global_position = target_pos + Vector2(-12.5, -400)
	hammer.scale = Vector2(2.0, 2.0)
	hammer.modulate = Color(1.5, 1.5, 2.0)

	var down_tween = TweenHelper.new_tween()
	down_tween.set_parallel(true)
	down_tween.tween_property(hammer, "global_position", target_pos - Vector2(12.5, 25), 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	down_tween.tween_property(hammer, "rotation", -TAU, 0.15)

	await down_tween.finished

	if is_instance_valid(hammer):
		hammer.queue_free()

func _create_lightning_strike(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Main lightning bolt from sky
	var bolt = ColorRect.new()
	bolt.size = Vector2(20, 600)
	bolt.color = Color(0.7, 0.85, 1.0, 0.95)
	bolt.pivot_offset = Vector2(10, 600)
	bolt.global_position = pos - Vector2(10, 0)
	bolt.z_index = 100
	scene.add_child(bolt)

	# Core bright line
	var core = ColorRect.new()
	core.size = Vector2(6, 600)
	core.color = Color(1.0, 1.0, 1.0, 1.0)
	core.pivot_offset = Vector2(3, 600)
	core.position = Vector2(7, 0)
	bolt.add_child(core)

	# Lightning branches
	for i in range(8):
		var branch = ColorRect.new()
		branch.size = Vector2(randf_range(60, 120), 4)
		branch.color = Color(0.6, 0.8, 1.0, 0.8)
		branch.pivot_offset = Vector2(0, 2)
		var y_pos = randf_range(100, 500)
		branch.position = Vector2(10, -y_pos)
		branch.rotation = randf_range(-0.5, 0.5) + (PI/2 if randf() > 0.5 else -PI/2)
		bolt.add_child(branch)

	# Impact flash
	var flash = ColorRect.new()
	flash.size = Vector2(200, 200)
	flash.color = Color(1.0, 1.0, 1.0, 0.9)
	flash.pivot_offset = Vector2(100, 100)
	flash.global_position = pos - Vector2(100, 100)
	flash.z_index = 99
	scene.add_child(flash)

	# Shockwave
	var wave = ColorRect.new()
	wave.size = Vector2(100, 100)
	wave.color = Color(0.5, 0.7, 1.0, 0.6)
	wave.pivot_offset = Vector2(50, 50)
	wave.global_position = pos - Vector2(50, 50)
	scene.add_child(wave)

	# Animations
	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(bolt, "modulate:a", 0.0, 0.2)
	tween.tween_property(flash, "scale", Vector2(3.0, 3.0), 0.15)
	tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	tween.tween_property(wave, "scale", Vector2(6.0, 6.0), 0.3)
	tween.tween_property(wave, "modulate:a", 0.0, 0.3)

	tween.set_parallel(false)
	tween.tween_callback(bolt.queue_free)
	tween.tween_callback(flash.queue_free)
	tween.tween_callback(wave.queue_free)

	# Electric sparks
	for i in range(12):
		var spark = ColorRect.new()
		spark.size = Vector2(4, 15)
		spark.color = Color(0.8, 0.9, 1.0)
		spark.pivot_offset = Vector2(2, 7.5)
		scene.add_child(spark)
		spark.global_position = pos

		var angle = randf() * TAU
		var dir = Vector2.from_angle(angle)
		var end_pos = pos + dir * randf_range(80, 180)

		var s_tween = TweenHelper.new_tween()
		s_tween.set_parallel(true)
		s_tween.tween_property(spark, "global_position", end_pos, 0.25)
		s_tween.tween_property(spark, "rotation", randf() * TAU, 0.25)
		s_tween.tween_property(spark, "modulate:a", 0.0, 0.25)
		s_tween.tween_callback(spark.queue_free)

func _mjolnir_impact(pos: Vector2, player: Node2D):
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
			continue

		var dist = enemy.global_position.distance_to(pos)
		if dist < MJOLNIR_RADIUS:
			var mjolnir_damage = damage * damage_multiplier * MJOLNIR_DAMAGE_MULT
			var falloff = 1.0 - (dist / MJOLNIR_RADIUS) * 0.4
			mjolnir_damage *= falloff

			if enemy.has_method("take_damage"):
				enemy.take_damage(mjolnir_damage, pos, 900.0, 0.5, player)
				dealt_damage.emit(enemy, mjolnir_damage)

func _chain_lightning(start_pos: Vector2, player: Node2D):
	var hit_enemies: Array = []
	var current_pos = start_pos

	for _chain in range(LIGHTNING_CHAINS):
		var nearest: Node2D = null
		var nearest_dist: float = 250.0

		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if enemy in hit_enemies:
				continue
			if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
				continue

			var dist = enemy.global_position.distance_to(current_pos)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = enemy

		if nearest:
			hit_enemies.append(nearest)
			_create_chain_bolt(current_pos, nearest.global_position)

			# Chain damage (reduced)
			var chain_damage = damage * damage_multiplier * 1.5
			if nearest.has_method("take_damage"):
				nearest.take_damage(chain_damage, current_pos, 200.0, 0.2, player)
				dealt_damage.emit(nearest, chain_damage)

			current_pos = nearest.global_position
		else:
			break

		await get_tree().create_timer(0.08).timeout

func _create_chain_bolt(from_pos: Vector2, to_pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	var direction = (to_pos - from_pos)
	var length = direction.length()
	var angle = direction.angle()

	var bolt = ColorRect.new()
	bolt.size = Vector2(length, 6)
	bolt.color = Color(0.6, 0.8, 1.0, 0.9)
	bolt.pivot_offset = Vector2(0, 3)
	bolt.global_position = from_pos
	bolt.rotation = angle
	scene.add_child(bolt)

	var tween = TweenHelper.new_tween()
	tween.tween_property(bolt, "modulate:a", 0.0, 0.15)
	tween.tween_callback(bolt.queue_free)

func _on_combo_finisher_hit(_target: Node2D):
	# Extra massive shake on finisher
	if DamageNumberManager:
		DamageNumberManager.shake(0.6)

# Block attacks during earthquake
func attack(direction: Vector2, player_damage_multiplier: float = 1.0) -> bool:
	if is_earthquaking:
		return false
	return super.attack(direction, player_damage_multiplier)
