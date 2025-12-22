# SCRIPT: FrostStaff.gd
# ATTACH TO: FrostStaff (Node2D) root node in FrostStaff.tscn
# LOCATION: res://Scripts/Weapons/FrostStaff.gd
# Ice staff with slowing ice shard projectiles and Blizzard skill

class_name FrostStaff
extends MagicWeapon

# ============================================
# PROJECTILE COLORS
# ============================================
const ICE_CORE: Color = Color(0.7, 0.9, 1.0)  # Light ice blue
const ICE_GLOW: Color = Color(0.5, 0.8, 1.0, 0.6)  # Frosty blue
const ICE_CRYSTAL: Color = Color(0.9, 0.95, 1.0)  # Near-white crystal

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
	# Frost Staff - moderate speed, slowing effect on hit
	attack_cooldown = 0.32  # Moderate speed
	projectile_spread = 3.0
	multi_shot = 1
	damage = 10.0
	damage_type = DamageTypes.Type.ICE  # Applies CHILL status effect

	staff_color = Color(0.4, 0.7, 1.0)  # Ice blue
	muzzle_flash_color = Color(0.6, 0.9, 1.0)

	# Attack Speed Limits (moderate speed, utility-focused)
	max_attacks_per_second = 3.0  # Moderate speed
	min_cooldown = 0.20  # Cannot cast faster than this

	# Skill settings - Blizzard
	skill_cooldown = 10.0
	beam_damage = 40.0

func _get_projectile_color() -> Color:
	return ICE_CORE

func _get_beam_color() -> Color:
	return Color(0.6, 0.9, 1.0, 1.0)

func _get_beam_glow_color() -> Color:
	return ICE_GLOW

# ============================================
# PROJECTILE CUSTOMIZATION - Ice shard visuals and slow effect
# ============================================
# Note: We use the base class _fire_projectiles which correctly aims at the mouse
# and only override _customize_projectile for visual effects

func _customize_projectile(projectile: Node2D):
	# Sharp ice shard projectile
	if projectile.has_node("Sprite"):
		var sprite_node = projectile.get_node("Sprite")
		sprite_node.color = ICE_CORE
		sprite_node.size = Vector2(10, 20)  # Shard shape - longer than wide

	# Add frost trail effect
	_add_frost_trail(projectile)

	# Connect to apply slow on hit using a safer approach
	if projectile.has_signal("hit_enemy"):
		projectile.hit_enemy.connect(_on_projectile_hit_enemy)
	if projectile.has_signal("projectile_hit"):
		# Use CONNECT_ONE_SHOT to auto-disconnect after first call
		# Also check self validity before calling
		var staff_ref = weakref(self)
		projectile.projectile_hit.connect(func(target, _dmg):
			var staff = staff_ref.get_ref()
			if staff:
				staff._on_projectile_hit_enemy(target)
		)

func _add_frost_trail(projectile: Node2D):
	var timer = Timer.new()
	timer.wait_time = 0.04
	timer.one_shot = false
	projectile.add_child(timer)

	# Use weakref to safely capture self
	var staff_ref = weakref(self)

	timer.timeout.connect(func():
		if not is_instance_valid(projectile):
			timer.stop()
			timer.queue_free()
			return

		# Check if staff is still valid using weakref
		var staff = staff_ref.get_ref()
		if not staff:
			timer.stop()
			timer.queue_free()
			return

		# Ice crystal particle
		var crystal = ColorRect.new()
		crystal.size = Vector2(6, 10)
		crystal.color = ICE_CRYSTAL if randf() > 0.6 else ICE_GLOW
		crystal.pivot_offset = Vector2(3, 5)
		staff.get_tree().current_scene.add_child(crystal)
		crystal.global_position = projectile.global_position
		crystal.rotation = randf_range(-PI/4, PI/4)

		# Float and fade
		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(crystal, "global_position:y", crystal.global_position.y - 15, 0.3)
		tween.tween_property(crystal, "global_position:x", crystal.global_position.x + randf_range(-10, 10), 0.3)
		tween.tween_property(crystal, "modulate:a", 0.0, 0.3)
		tween.tween_property(crystal, "scale", Vector2(0.3, 0.3), 0.3)
		tween.tween_callback(crystal.queue_free)

		# Occasional snowflake
		if randf() > 0.7:
			staff._spawn_trail_snowflake(projectile.global_position)
	)
	timer.start()

func _spawn_trail_snowflake(pos: Vector2):
	var snow = ColorRect.new()
	snow.size = Vector2(4, 4)
	snow.color = ICE_CRYSTAL
	snow.pivot_offset = Vector2(2, 2)
	get_tree().current_scene.add_child(snow)
	snow.global_position = pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(snow, "global_position:y", snow.global_position.y + 20, 0.4)
	tween.tween_property(snow, "rotation", randf() * TAU, 0.4)
	tween.tween_property(snow, "modulate:a", 0.0, 0.4)
	tween.tween_callback(snow.queue_free)

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

		var tween = TweenHelper.new_tween()
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
	var spawn_tween = TweenHelper.new_tween()
	spawn_tween.tween_property(base_visual, "scale", Vector2(1, 1), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Start blizzard effect
	_run_blizzard(blizzard, base_visual, pos)

func _run_blizzard(blizzard: Node2D, visual: ColorRect, center: Vector2):
	var elapsed = 0.0
	var tick_timer = 0.0

	# Store weakref for safe access after await
	var staff_ref = weakref(self)

	while elapsed < blizzard_duration:
		# Check blizzard validity first
		if not is_instance_valid(blizzard):
			break

		var delta = get_process_delta_time()
		elapsed += delta
		tick_timer += delta

		# Spawn snowflake particles (only if staff valid)
		var staff = staff_ref.get_ref()
		if staff and randf() < 0.3:
			staff._spawn_snowflake(center)

		# Damage tick
		if tick_timer >= blizzard_tick_rate:
			tick_timer = 0.0
			if staff:
				staff._blizzard_damage_tick(center)

		# Fade out near end
		if elapsed > blizzard_duration - 1.0 and is_instance_valid(visual):
			var fade = (blizzard_duration - elapsed) / 1.0
			visual.modulate.a = 0.3 * fade

		await get_tree().process_frame

		# Check validity after await - both staff and blizzard
		if not staff_ref.get_ref():
			if is_instance_valid(blizzard):
				blizzard.queue_free()
			return

		# Also check blizzard after await
		if not is_instance_valid(blizzard):
			break

	# Cleanup
	if is_instance_valid(blizzard):
		blizzard.queue_free()

func _blizzard_damage_tick(center: Vector2):
	var enemies = _get_enemies()
	var attacker = player_reference if is_instance_valid(player_reference) else null

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var distance = enemy.global_position.distance_to(center)
		if distance < blizzard_radius:
			# Deal damage with ICE type to apply CHILL
			var tick_damage = blizzard_damage_per_tick * damage_multiplier
			if enemy.has_method("take_damage"):
				enemy.take_damage(tick_damage, center, 50.0, 0.05, attacker, damage_type)

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
	var tween = TweenHelper.new_tween()
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
	var recoil_tween = TweenHelper.new_tween()
	recoil_tween.tween_property(self, "position:x", -15, 0.1)
	recoil_tween.tween_property(self, "position:x", 0, 0.2)

	# Muzzle flash
	muzzle_flash.modulate = Color(0.6, 0.9, 1.0, 1.0)
	var flash_tween = TweenHelper.new_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.2)

	# Return to normal color
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(self) and sprite:
		sprite.color = original_color

func _play_attack_animation():
	# Ice blue muzzle flash
	muzzle_flash.modulate.a = 1.0
	muzzle_flash.color = Color(0.6, 0.9, 1.0)
	var flash_tween = TweenHelper.new_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.1)

	# Staff recoil
	var recoil_tween = TweenHelper.new_tween()
	recoil_tween.tween_property(self, "position:x", -10, 0.05)
	recoil_tween.tween_property(self, "position:x", 0, 0.1)

	# Brief ice glow
	sprite.color = Color(0.6, 0.9, 1.0)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self) and sprite:
		sprite.color = staff_color
