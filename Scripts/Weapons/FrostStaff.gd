# SCRIPT: FrostStaff.gd
# ATTACH TO: FrostStaff (Node2D) root node in FrostStaff.tscn
# LOCATION: res://Scripts/Weapons/FrostStaff.gd
# Ice staff with slowing effects and Blizzard skill

class_name FrostStaff
extends MagicWeapon

# ============================================
# FROST STAFF SPECIFIC
# ============================================
const FROST_PROJECTILE_SCENE = preload("res://Scenes/Spells/BasicProjectile.tscn")

# Slow effect settings
var slow_duration: float = 2.0
var slow_amount: float = 0.5  # 50% slow

# Blizzard skill settings
var blizzard_radius: float = 150.0
var blizzard_duration: float = 4.0
var blizzard_damage_per_tick: float = 5.0
var blizzard_tick_rate: float = 0.5

func _weapon_ready():
	# Frost Staff settings
	attack_cooldown = 0.35
	projectile_spread = 3.0
	multi_shot = 1
	damage = 10.0

	staff_color = Color(0.4, 0.7, 1.0)  # Ice blue
	muzzle_flash_color = Color(0.6, 0.9, 1.0)

	# Skill settings
	skill_cooldown = 10.0
	beam_damage = 40.0

func _get_projectile_color() -> Color:
	return Color(0.5, 0.8, 1.0)  # Ice blue

func _get_beam_color() -> Color:
	return Color(0.6, 0.9, 1.0, 1.0)

func _get_beam_glow_color() -> Color:
	return Color(0.4, 0.7, 1.0, 0.6)

# ============================================
# OVERRIDE PROJECTILE FIRING - Add slow effect
# ============================================
func _fire_projectiles(direction: Vector2):
	for i in range(multi_shot):
		if not projectile_scene:
			continue

		var projectile = projectile_scene.instantiate()
		get_tree().root.add_child(projectile)

		# Calculate spread
		var spread_angle = _calculate_spread_angle(i)
		var final_direction = direction.rotated(spread_angle)

		# Initialize projectile
		projectile.initialize(
			projectile_spawn.global_position,
			final_direction,
			damage_multiplier,
			300.0,  # Lower knockback
			0.1,
			player_reference
		)

		# Override projectile color to ice blue
		if projectile.has_node("Sprite"):
			projectile.get_node("Sprite").color = _get_projectile_color()

		# Connect to apply slow on hit
		if projectile.has_signal("hit_enemy"):
			projectile.hit_enemy.connect(_on_projectile_hit_enemy)

		projectile_fired.emit(projectile)

func _on_projectile_hit_enemy(enemy: Node2D):
	_apply_slow_effect(enemy)

func _apply_slow_effect(enemy: Node2D):
	if not is_instance_valid(enemy):
		return

	# Apply slow (if enemy has speed property)
	if enemy.has_method("apply_slow"):
		enemy.apply_slow(slow_amount, slow_duration)
	elif "speed" in enemy or "move_speed" in enemy:
		# Fallback: directly modify speed temporarily
		_temporary_slow(enemy)

	# Visual frost effect
	_create_frost_effect(enemy.global_position)

func _temporary_slow(enemy: Node2D):
	var speed_property = "speed" if "speed" in enemy else "move_speed"
	var original_speed = enemy.get(speed_property)

	# Apply slow
	enemy.set(speed_property, original_speed * slow_amount)

	# Ice visual on enemy
	var original_modulate = enemy.modulate
	enemy.modulate = Color(0.6, 0.8, 1.0)

	# Create timer to restore
	var timer = get_tree().create_timer(slow_duration)
	timer.timeout.connect(func():
		if is_instance_valid(enemy):
			enemy.set(speed_property, original_speed)
			enemy.modulate = original_modulate
	)

func _create_frost_effect(pos: Vector2):
	# Ice crystal particles
	for i in range(4):
		var crystal = ColorRect.new()
		crystal.size = Vector2(8, 12)
		crystal.color = Color(0.7, 0.9, 1.0, 0.9)
		crystal.pivot_offset = Vector2(4, 6)
		get_tree().current_scene.add_child(crystal)
		crystal.global_position = pos + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		crystal.rotation = randf_range(-PI/4, PI/4)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(crystal, "global_position:y", crystal.global_position.y - 30, 0.4)
		tween.tween_property(crystal, "modulate:a", 0.0, 0.4)
		tween.tween_property(crystal, "scale", Vector2(0.5, 0.5), 0.4)
		tween.tween_callback(crystal.queue_free)

# ============================================
# BLIZZARD SKILL - AoE slow zone
# ============================================
func _perform_skill() -> bool:
	if not player_reference:
		return false

	var target_pos = player_reference.get_global_mouse_position()

	# Create blizzard at target location
	_create_blizzard(target_pos)

	# Visual feedback on staff
	_play_skill_animation()

	return true

func _create_blizzard(pos: Vector2):
	# Create blizzard zone node
	var blizzard = Node2D.new()
	blizzard.global_position = pos
	get_tree().current_scene.add_child(blizzard)

	# Visual base (ice ring)
	var base_visual = ColorRect.new()
	base_visual.size = Vector2(blizzard_radius * 2, blizzard_radius * 2)
	base_visual.color = Color(0.5, 0.8, 1.0, 0.3)
	base_visual.pivot_offset = Vector2(blizzard_radius, blizzard_radius)
	base_visual.position = -Vector2(blizzard_radius, blizzard_radius)
	blizzard.add_child(base_visual)

	# Spawn animation
	base_visual.scale = Vector2(0.3, 0.3)
	var spawn_tween = create_tween()
	spawn_tween.tween_property(base_visual, "scale", Vector2(1, 1), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Start blizzard effect
	_run_blizzard(blizzard, base_visual, pos)

func _run_blizzard(blizzard: Node2D, visual: ColorRect, center: Vector2):
	var elapsed = 0.0
	var tick_timer = 0.0

	while elapsed < blizzard_duration:
		if not is_instance_valid(blizzard):
			break

		var delta = get_process_delta_time()
		elapsed += delta
		tick_timer += delta

		# Spawn snowflake particles
		if randf() < 0.3:
			_spawn_snowflake(center)

		# Damage tick
		if tick_timer >= blizzard_tick_rate:
			tick_timer = 0.0
			_blizzard_damage_tick(center)

		# Fade out near end
		if elapsed > blizzard_duration - 1.0:
			var fade = (blizzard_duration - elapsed) / 1.0
			visual.modulate.a = 0.3 * fade

		await get_tree().process_frame

	# Cleanup
	if is_instance_valid(blizzard):
		blizzard.queue_free()

func _blizzard_damage_tick(center: Vector2):
	var enemies = _get_enemies()

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var distance = enemy.global_position.distance_to(center)
		if distance < blizzard_radius:
			# Deal damage
			var tick_damage = blizzard_damage_per_tick * damage_multiplier
			if enemy.has_method("take_damage"):
				enemy.take_damage(tick_damage, center, 50.0, 0.05, player_reference)

			# Apply slow
			_apply_slow_effect(enemy)

func _spawn_snowflake(center: Vector2):
	var snowflake = ColorRect.new()
	snowflake.size = Vector2(6, 6)
	snowflake.color = Color(0.9, 0.95, 1.0, 0.8)
	snowflake.pivot_offset = Vector2(3, 3)
	get_tree().current_scene.add_child(snowflake)

	# Random position within blizzard radius
	var angle = randf() * TAU
	var dist = randf() * blizzard_radius
	snowflake.global_position = center + Vector2.from_angle(angle) * dist + Vector2(0, -50)

	# Fall animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(snowflake, "global_position:y", snowflake.global_position.y + 80, 0.8)
	tween.tween_property(snowflake, "global_position:x", snowflake.global_position.x + randf_range(-20, 20), 0.8)
	tween.tween_property(snowflake, "rotation", randf_range(-PI, PI), 0.8)
	tween.tween_property(snowflake, "modulate:a", 0.0, 0.8)
	tween.tween_callback(snowflake.queue_free)

func _play_skill_animation():
	# Staff glow ice blue during skill
	var original_color = sprite.color
	sprite.color = Color(0.6, 0.9, 1.0)

	# Recoil
	var recoil_tween = create_tween()
	recoil_tween.tween_property(self, "position:x", -15, 0.1)
	recoil_tween.tween_property(self, "position:x", 0, 0.2)

	# Muzzle flash
	muzzle_flash.modulate = Color(0.6, 0.9, 1.0, 1.0)
	var flash_tween = create_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.2)

	# Return to normal color
	await get_tree().create_timer(0.3).timeout
	sprite.color = original_color

func _play_attack_animation():
	# Ice blue muzzle flash
	muzzle_flash.modulate.a = 1.0
	muzzle_flash.color = Color(0.6, 0.9, 1.0)
	var flash_tween = create_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.1)

	# Staff recoil
	var recoil_tween = create_tween()
	recoil_tween.tween_property(self, "position:x", -10, 0.05)
	recoil_tween.tween_property(self, "position:x", 0, 0.1)

	# Brief ice glow
	sprite.color = Color(0.6, 0.9, 1.0)
	await get_tree().create_timer(0.1).timeout
	sprite.color = staff_color
