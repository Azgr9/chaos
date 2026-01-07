# SCRIPT: Katana.gd
# ATTACH TO: Katana (Node2D) root node in Katana.tscn
# LOCATION: res://Scripts/Weapons/Katana.gd

class_name Katana
extends MeleeWeapon

# ============================================
# KATANA-SPECIFIC STATE
# ============================================
var is_dash_slashing: bool = false
var _dash_tween: Tween = null

# Dash slash settings
const DASH_DISTANCE: float = 600.0
const DASH_TIME: float = 0.15
const DASH_HIT_RADIUS: float = 120.0
const DASH_DAMAGE_MULTIPLIER: float = 1.5

# Visual colors - Red themed katana
const KATANA_BLADE_COLOR: Color = Color(0.85, 0.15, 0.15)  # Deep red blade
const KATANA_ACCENT_COLOR: Color = Color(1.0, 0.3, 0.3)  # Bright red accent
const KATANA_TRAIL_COLOR: Color = Color(1.0, 0.2, 0.2, 0.8)  # Red trail
const KATANA_SLASH_COLOR: Color = Color(1.0, 0.4, 0.4, 0.9)  # Light red slash
const KATANA_GLOW_COLOR: Color = Color(1.0, 0.6, 0.4)  # Orange-red glow

# Shaders
var slash_shader: Shader = preload("res://Scenes/Weapons/Katana/SlashTrail.gdshader")
var ghost_shader: Shader = preload("res://Scenes/Weapons/Katana/DashGhost.gdshader")

func _weapon_ready():
	# Katana - fast, precise, combo-focused
	damage = 12.0
	attack_duration = 0.16  # Very fast swings
	attack_cooldown = 0.24  # Quick recovery for combos
	weapon_color = KATANA_BLADE_COLOR
	idle_rotation = 45.0
	idle_scale = Vector2(0.6, 0.6)

	# Cone Hitbox - Now configured via @export in scene inspector
	# attack_range = 115.0  # Good range for quick slashes
	# attack_cone_angle = 85.0  # Focused but effective arc

	# Attack Speed Limits (fast weapon)
	max_attacks_per_second = 4.5  # Fastest melee weapon
	min_cooldown = 0.14  # Can go very fast

	# Combo settings - optimized for rapid combos
	combo_window = 2.0
	combo_finisher_multiplier = 1.6
	combo_hits = 3

	# Moderate knockback (precision over power)
	base_knockback = 280.0
	finisher_knockback = 500.0

	# Skill settings
	skill_cooldown = 6.0

func _get_attack_pattern(attack_index: int) -> String:
	# Katana: quick slash -> reverse slash -> overhead slash
	match attack_index:
		1: return "horizontal"
		2: return "horizontal_reverse"
		3: return "overhead"
		_: return "horizontal"

func _get_hit_color(combo_finisher: bool, dash_attack: bool, crit: bool) -> Color:
	if crit:
		return Color.RED
	elif combo_finisher:
		return Color.GOLD
	elif dash_attack or is_dash_slashing:
		return KATANA_ACCENT_COLOR
	return KATANA_BLADE_COLOR

# Visual swing trail for Katana - sharp, fast streaks
func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	# Call parent animation
	super._perform_attack_animation(pattern, duration, is_dash_attack)

	# Add katana slash trail - multiple sharp lines
	_create_katana_slash_trail()

func _create_katana_slash_trail():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Sharp slash lines with shader - oriented to attack direction
	for i in range(3):
		var slash = ColorRect.new()
		slash.size = Vector2(weapon_length * 1.0, 12)
		slash.pivot_offset = Vector2(0, 6)
		scene.add_child(slash)
		slash.global_position = global_position + current_attack_direction * 20
		slash.rotation = current_attack_direction.angle() + (i - 1) * 0.08

		var mat = ShaderMaterial.new()
		mat.shader = slash_shader
		mat.set_shader_parameter("slash_color", KATANA_TRAIL_COLOR)
		mat.set_shader_parameter("glow_color", KATANA_GLOW_COLOR)
		mat.set_shader_parameter("glow_intensity", 2.0)
		mat.set_shader_parameter("edge_sharpness", 4.0)
		mat.set_shader_parameter("progress", 0.0)
		slash.material = mat

		var tween = TweenHelper.new_tween()
		tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.12)
		tween.tween_callback(slash.queue_free)

func _on_combo_finisher_hit(_target: Node2D):
	# Red cross slash effect
	DamageNumberManager.shake(0.25)
	_create_cross_slash_effect()

# ============================================
# KATANA DASH SLASH SKILL
# ============================================

## Dash slash is async - manages its own invulnerability
func _is_async_skill() -> bool:
	return true

func _perform_skill() -> bool:
	if not player_reference:
		return false

	is_dash_slashing = true
	_execute_dash_slash()
	return true

func _execute_dash_slash():
	var player = player_reference
	if not is_instance_valid(player):
		is_dash_slashing = false
		_end_skill_invulnerability()
		return

	# IMMEDIATELY make player invulnerable - before anything else
	player.is_invulnerable = true

	# Calculate dash direction toward mouse
	var direction = (player.get_global_mouse_position() - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	var desired_position = player.global_position + direction * DASH_DISTANCE

	# Wall-safe raycast
	var target_position = _calculate_safe_dash_position(player, desired_position, direction)

	# Visual feedback - slight transparency during dash
	player.modulate = Color(1, 1, 1, 0.5)

	# Kill any existing dash tween
	if _dash_tween and _dash_tween.is_valid():
		_dash_tween.kill()

	# Perform dash movement - store reference for cleanup
	_dash_tween = TweenHelper.new_tween()
	_dash_tween.tween_property(player, "global_position", target_position, DASH_TIME)\
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)

	# Use weakref for safe callback
	var katana_ref = weakref(self)
	var player_ref = weakref(player)
	_dash_tween.finished.connect(func():
		var katana = katana_ref.get_ref()
		var p = player_ref.get_ref()
		if katana:
			katana._on_dash_slash_finished(p)
	)

	# Visual effects
	_create_slash_effect(player.global_position)
	_create_dash_trail()

	# Damage enemies during dash
	_dash_damage_loop(player, direction)

func _on_dash_slash_finished(player: Node2D):
	if is_instance_valid(player):
		player.is_invulnerable = false
		player.modulate = Color.WHITE
	is_dash_slashing = false
	_dash_tween = null
	_end_skill_invulnerability()

func _calculate_safe_dash_position(player: Node2D, desired: Vector2, direction: Vector2) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(player.global_position, desired)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	# Exclude player and enemies from ray
	var exclude: Array = [player]
	exclude.append_array(get_tree().get_nodes_in_group("enemies"))
	query.exclude = exclude

	var result = space_state.intersect_ray(query)

	if result and result.has("position"):
		return result.position - direction * 16.0
	return desired

func _dash_damage_loop(player: Node2D, _direction: Vector2):
	var checks = 5
	var hit_enemies: Array = []

	for i in range(checks):
		await get_tree().create_timer(DASH_TIME / checks).timeout

		# Check validity after await
		if not is_instance_valid(self) or not is_instance_valid(player):
			return

		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if enemy in hit_enemies:
				continue
			if enemy.global_position.distance_to(player.global_position) < DASH_HIT_RADIUS:
				hit_enemies.append(enemy)
				var final_damage = damage * damage_multiplier * DASH_DAMAGE_MULTIPLIER

				if enemy.has_method("take_damage"):
					enemy.take_damage(final_damage, player.global_position, 300.0, 0.15, player)
					dealt_damage.emit(enemy, final_damage)
					_create_slash_effect(enemy.global_position)

func _create_dash_trail():
	if not player_reference:
		return

	# Create main slash line with shader
	_create_shader_slash_trail()

	# Create ghost afterimages
	for i in range(8):
		await get_tree().create_timer(0.018).timeout

		if not is_instance_valid(self) or not is_instance_valid(player_reference):
			return

		_create_ghost_afterimage(i / 8.0)

# ============================================
# VISUAL EFFECTS
# ============================================

func _create_shader_slash_trail():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	var direction = (player_reference.get_global_mouse_position() - player_reference.global_position).normalized()

	# Main slash trail with shader
	var slash = ColorRect.new()
	slash.size = Vector2(DASH_DISTANCE * 1.2, 40)
	slash.pivot_offset = Vector2(0, 20)
	slash.global_position = player_reference.global_position - Vector2(0, 20)
	slash.rotation = direction.angle()

	# Apply shader
	var mat = ShaderMaterial.new()
	mat.shader = slash_shader
	mat.set_shader_parameter("slash_color", KATANA_SLASH_COLOR)
	mat.set_shader_parameter("glow_color", KATANA_GLOW_COLOR)
	mat.set_shader_parameter("glow_intensity", 2.0)
	mat.set_shader_parameter("edge_sharpness", 4.0)
	mat.set_shader_parameter("progress", 0.0)
	slash.material = mat

	scene.add_child(slash)

	# Animate progress
	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.35)
	tween.tween_callback(slash.queue_free)

	# Secondary thin slash lines
	for i in range(3):
		var thin_slash = ColorRect.new()
		thin_slash.size = Vector2(DASH_DISTANCE * 0.9, 8)
		thin_slash.pivot_offset = Vector2(0, 4)
		thin_slash.global_position = player_reference.global_position + Vector2(0, (i - 1) * 12)
		thin_slash.rotation = direction.angle() + (i - 1) * 0.05

		var thin_mat = ShaderMaterial.new()
		thin_mat.shader = slash_shader
		thin_mat.set_shader_parameter("slash_color", Color(1.0, 0.4, 0.3, 0.7))
		thin_mat.set_shader_parameter("glow_color", Color(1.0, 1.0, 0.8))
		thin_mat.set_shader_parameter("glow_intensity", 1.5)
		thin_mat.set_shader_parameter("progress", 0.0)
		thin_slash.material = thin_mat

		scene.add_child(thin_slash)

		var thin_tween = TweenHelper.new_tween()
		thin_tween.tween_method(func(p): thin_mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.25 + i * 0.05)
		thin_tween.tween_callback(thin_slash.queue_free)

func _create_ghost_afterimage(_progress: float):
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Ghost rectangle with shader
	var ghost = ColorRect.new()
	ghost.size = Vector2(50, 50)
	ghost.pivot_offset = Vector2(25, 25)
	ghost.global_position = player_reference.global_position - Vector2(25, 25)

	# Apply ghost shader
	var mat = ShaderMaterial.new()
	mat.shader = ghost_shader
	mat.set_shader_parameter("ghost_color", Color(1.0, 0.25, 0.2, 0.7))
	mat.set_shader_parameter("distortion_amount", 0.03)
	mat.set_shader_parameter("scan_line_density", 50.0)
	mat.set_shader_parameter("progress", 0.0)
	ghost.material = mat

	scene.add_child(ghost)

	# Fade out with shader progress
	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.25)
	tween.tween_callback(ghost.queue_free)

func _create_slash_effect(hit_position: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Create X-shaped slash marks with glow
	for i in range(4):
		var slash = ColorRect.new()
		slash.size = Vector2(6, 35)
		slash.pivot_offset = Vector2(3, 17.5)
		slash.global_position = hit_position

		# Apply shader for glow
		var mat = ShaderMaterial.new()
		mat.shader = slash_shader
		mat.set_shader_parameter("slash_color", KATANA_ACCENT_COLOR)
		mat.set_shader_parameter("glow_color", Color(1.0, 0.8, 0.6))
		mat.set_shader_parameter("glow_intensity", 2.5)
		mat.set_shader_parameter("progress", 0.0)
		slash.material = mat

		# Rotate in X pattern
		slash.rotation = (PI / 4) * i

		scene.add_child(slash)

		# Scale up and fade
		slash.scale = Vector2(0.3, 0.3)
		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(slash, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.2)
		tween.tween_callback(slash.queue_free)

	# Spark particles
	for i in range(6):
		var spark = ColorRect.new()
		spark.size = Vector2(4, 12)
		spark.color = Color(1.0, 0.9, 0.7)
		spark.pivot_offset = Vector2(2, 6)
		scene.add_child(spark)
		spark.global_position = hit_position

		var angle = randf() * TAU
		var dir = Vector2.from_angle(angle)
		spark.rotation = angle

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", hit_position + dir * randf_range(40, 70), 0.15)
		tween.tween_property(spark, "scale", Vector2(0.2, 0.2), 0.15)
		tween.tween_property(spark, "modulate:a", 0.0, 0.15)
		tween.tween_callback(spark.queue_free)

# Override attack to block during dash slash
func attack(direction: Vector2, player_damage_multiplier: float = 1.0) -> bool:
	if is_dash_slashing:
		return false
	return super.attack(direction, player_damage_multiplier)

func _create_cross_slash_effect():
	if not player_reference:
		return

	var hit_pos = player_reference.global_position + current_attack_direction * 60

	# Create X slash mark
	for i in range(2):
		var slash = ColorRect.new()
		slash.size = Vector2(6, 80)
		slash.color = KATANA_ACCENT_COLOR
		slash.pivot_offset = Vector2(3, 40)
		get_tree().current_scene.add_child(slash)
		slash.global_position = hit_pos
		slash.rotation = (PI / 4) if i == 0 else (-PI / 4)
		slash.scale = Vector2(0.5, 0.5)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(slash, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(slash, "modulate:a", 0.0, 0.2)
		tween.tween_callback(slash.queue_free)
