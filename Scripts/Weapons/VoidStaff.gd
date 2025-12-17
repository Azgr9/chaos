# SCRIPT: VoidStaff.gd
# ATTACH TO: VoidStaff (Node2D) root node in VoidStaff.tscn
# LOCATION: res://Scripts/Weapons/VoidStaff.gd
# Dark magic staff with Black Hole skill - pulls enemies and deals AoE damage

class_name VoidStaff
extends MagicWeapon

# ============================================
# VOID STAFF SPECIFIC
# ============================================

# Black Hole skill settings
var black_hole_radius: float = 180.0
var black_hole_duration: float = 3.0
var black_hole_damage_per_tick: float = 12.0
var black_hole_tick_rate: float = 0.3
var black_hole_pull_strength: float = 150.0

func _weapon_ready():
	# Void Staff settings - higher damage, slower fire rate
	attack_cooldown = 0.5
	projectile_spread = 0.0  # Precise dark bolts
	multi_shot = 1
	damage = 18.0  # High damage per shot

	staff_color = Color(0.3, 0.1, 0.4)  # Dark purple
	muzzle_flash_color = Color(0.5, 0.2, 0.6)

	# Skill settings - powerful but long cooldown
	skill_cooldown = 14.0
	beam_damage = 60.0

func _get_projectile_color() -> Color:
	return Color(0.4, 0.1, 0.5)  # Dark purple

func _get_beam_color() -> Color:
	return Color(0.5, 0.2, 0.6, 1.0)

func _get_beam_glow_color() -> Color:
	return Color(0.3, 0.0, 0.4, 0.6)

# ============================================
# OVERRIDE PROJECTILE - Dark void bolts
# ============================================
func _fire_projectiles(direction: Vector2):
	for i in range(multi_shot):
		if not projectile_scene:
			continue

		var projectile = projectile_scene.instantiate()
		get_tree().root.add_child(projectile)

		var spread_angle = _calculate_spread_angle(i)
		var final_direction = direction.rotated(spread_angle)

		projectile.initialize(
			projectile_spawn.global_position,
			final_direction,
			damage_multiplier,
			200.0,  # Low knockback - void pulls, doesn't push
			0.15,
			player_reference
		)

		# Override projectile color to dark purple
		if projectile.has_node("Sprite"):
			projectile.get_node("Sprite").color = _get_projectile_color()

		# Add void trail effect
		_add_void_trail(projectile)

		projectile_fired.emit(projectile)

func _add_void_trail(projectile: Node2D):
	# Create trailing void particles
	var timer = Timer.new()
	timer.wait_time = 0.05
	timer.one_shot = false
	projectile.add_child(timer)

	timer.timeout.connect(func():
		if not is_instance_valid(projectile):
			timer.queue_free()
			return

		var trail = ColorRect.new()
		trail.size = Vector2(12, 12)
		trail.color = Color(0.3, 0.1, 0.4, 0.6)
		trail.pivot_offset = Vector2(6, 6)
		get_tree().current_scene.add_child(trail)
		trail.global_position = projectile.global_position

		var tween = projectile.create_tween()
		tween.set_parallel(true)
		tween.tween_property(trail, "scale", Vector2(0.3, 0.3), 0.2)
		tween.tween_property(trail, "modulate:a", 0.0, 0.2)
		tween.tween_callback(trail.queue_free)
	)
	timer.start()

# ============================================
# BLACK HOLE SKILL - Pull enemies and deal damage
# ============================================
func _perform_skill() -> bool:
	if not player_reference:
		return false

	var target_pos = player_reference.get_global_mouse_position()

	# Create black hole at target location
	_create_black_hole(target_pos)

	# Visual feedback on staff
	_play_skill_animation()

	return true

func _create_black_hole(pos: Vector2):
	# Create black hole container
	var black_hole = Node2D.new()
	black_hole.global_position = pos
	get_tree().current_scene.add_child(black_hole)

	# Visual - dark core
	var core = ColorRect.new()
	core.size = Vector2(40, 40)
	core.color = Color(0.1, 0.0, 0.15, 1.0)
	core.pivot_offset = Vector2(20, 20)
	core.position = Vector2(-20, -20)
	black_hole.add_child(core)

	# Visual - purple ring
	var ring = ColorRect.new()
	ring.size = Vector2(80, 80)
	ring.color = Color(0.4, 0.1, 0.5, 0.5)
	ring.pivot_offset = Vector2(40, 40)
	ring.position = Vector2(-40, -40)
	ring.z_index = -1
	black_hole.add_child(ring)

	# Spawn animation
	black_hole.scale = Vector2(0.1, 0.1)
	var spawn_tween = create_tween()
	spawn_tween.tween_property(black_hole, "scale", Vector2(1, 1), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Screen effect
	DamageNumberManager.shake(0.3)

	# Start black hole effect
	_run_black_hole(black_hole, core, ring, pos)

func _run_black_hole(black_hole: Node2D, core: ColorRect, ring: ColorRect, center: Vector2):
	var elapsed = 0.0
	var tick_timer = 0.0
	var rotation_speed = 3.0

	while elapsed < black_hole_duration:
		if not is_instance_valid(black_hole):
			break

		var delta = get_process_delta_time()
		elapsed += delta
		tick_timer += delta

		# Rotate visuals
		ring.rotation += delta * rotation_speed
		core.rotation -= delta * rotation_speed * 0.5

		# Pulsing effect
		var pulse = 1.0 + sin(elapsed * 5) * 0.1
		ring.scale = Vector2(pulse, pulse)

		# Pull enemies toward center
		_pull_enemies_to_center(center, delta)

		# Spawn void particles being sucked in
		if randf() < 0.4:
			_spawn_void_particle(center)

		# Damage tick
		if tick_timer >= black_hole_tick_rate:
			tick_timer = 0.0
			_black_hole_damage_tick(center)

		# Fade out near end
		if elapsed > black_hole_duration - 0.5:
			var fade = (black_hole_duration - elapsed) / 0.5
			black_hole.modulate.a = fade

		await get_tree().process_frame

	# Collapse animation
	if is_instance_valid(black_hole):
		var collapse_tween = create_tween()
		collapse_tween.tween_property(black_hole, "scale", Vector2(0.1, 0.1), 0.2)
		collapse_tween.tween_callback(black_hole.queue_free)

		# Final burst
		_create_void_burst(center)

func _pull_enemies_to_center(center: Vector2, delta: float):
	var enemies = _get_enemies()

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var to_center = center - enemy.global_position
		var distance = to_center.length()

		if distance < black_hole_radius and distance > 20:
			# Pull strength increases as enemies get closer
			var pull_factor = 1.0 - (distance / black_hole_radius)
			var pull_force = to_center.normalized() * black_hole_pull_strength * pull_factor * delta

			# Move enemy toward center
			enemy.global_position += pull_force

func _black_hole_damage_tick(center: Vector2):
	var enemies = _get_enemies()

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var distance = enemy.global_position.distance_to(center)
		if distance < black_hole_radius:
			# More damage at center
			var damage_factor = 1.0 + (1.0 - distance / black_hole_radius) * 0.5
			var tick_damage = black_hole_damage_per_tick * damage_multiplier * damage_factor

			if enemy.has_method("take_damage"):
				enemy.take_damage(tick_damage, center, 0.0, 0.1, player_reference)

			# Void hit effect
			_create_void_hit_effect(enemy.global_position)

func _spawn_void_particle(center: Vector2):
	var particle = ColorRect.new()
	particle.size = Vector2(10, 10)
	particle.color = Color(0.5, 0.2, 0.6, 0.8)
	particle.pivot_offset = Vector2(5, 5)
	get_tree().current_scene.add_child(particle)

	# Start at edge of radius
	var angle = randf() * TAU
	var start_pos = center + Vector2.from_angle(angle) * black_hole_radius
	particle.global_position = start_pos

	# Spiral toward center
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(particle, "global_position", center, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(particle, "scale", Vector2(0.2, 0.2), 0.5)
	tween.tween_property(particle, "rotation", randf_range(PI, TAU), 0.5)
	tween.tween_callback(particle.queue_free)

func _create_void_hit_effect(pos: Vector2):
	var flash = ColorRect.new()
	flash.size = Vector2(16, 16)
	flash.color = Color(0.5, 0.2, 0.6, 0.8)
	flash.pivot_offset = Vector2(8, 8)
	get_tree().current_scene.add_child(flash)
	flash.global_position = pos - Vector2(8, 8)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(0.3, 0.3), 0.15)
	tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)

func _create_void_burst(center: Vector2):
	# Final explosion when black hole collapses
	DamageNumberManager.shake(0.4)

	for i in range(12):
		var particle = ColorRect.new()
		particle.size = Vector2(20, 20)
		particle.color = Color(0.4, 0.1, 0.5, 0.9)
		particle.pivot_offset = Vector2(10, 10)
		get_tree().current_scene.add_child(particle)
		particle.global_position = center

		var angle = (TAU / 12) * i
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(100, 180)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", center + dir * dist, 0.3)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_property(particle, "scale", Vector2(0.5, 0.5), 0.3)
		tween.tween_callback(particle.queue_free)

func _play_skill_animation():
	# Staff glow dark purple during skill
	var original_color = sprite.color
	sprite.color = Color(0.5, 0.2, 0.6)

	# Strong recoil
	var recoil_tween = create_tween()
	recoil_tween.tween_property(self, "position:x", -20, 0.1)
	recoil_tween.tween_property(self, "position:x", 0, 0.2)

	# Muzzle flash
	muzzle_flash.modulate = Color(0.5, 0.2, 0.6, 1.0)
	var flash_tween = create_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.2)

	# Return to normal color
	await get_tree().create_timer(0.3).timeout
	sprite.color = original_color

func _play_attack_animation():
	# Dark purple muzzle flash
	muzzle_flash.modulate.a = 1.0
	muzzle_flash.color = Color(0.5, 0.2, 0.6)
	var flash_tween = create_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.1)

	# Staff recoil
	var recoil_tween = create_tween()
	recoil_tween.tween_property(self, "position:x", -12, 0.05)
	recoil_tween.tween_property(self, "position:x", 0, 0.1)

	# Brief void glow
	sprite.color = Color(0.5, 0.2, 0.6)
	await get_tree().create_timer(0.1).timeout
	sprite.color = staff_color
