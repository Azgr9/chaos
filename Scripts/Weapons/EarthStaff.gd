# SCRIPT: EarthStaff.gd
# ATTACH TO: EarthStaff (Node2D) root node in EarthStaff.tscn
# LOCATION: res://Scripts/Weapons/EarthStaff.gd
# Earth/rock themed staff with boulder projectiles and Earthquake skill

class_name EarthStaff
extends MagicWeapon

# ============================================
# PROJECTILE COLORS
# ============================================
const EARTH_CORE: Color = Color(0.5, 0.4, 0.25)  # Brown rock
const EARTH_DARK: Color = Color(0.35, 0.28, 0.18)  # Dark earth
const EARTH_LIGHT: Color = Color(0.65, 0.55, 0.4)  # Light stone
const EARTH_GLOW: Color = Color(0.7, 0.55, 0.3)  # Warm glow
const CRYSTAL_COLOR: Color = Color(0.4, 0.6, 0.35)  # Green crystal accent

# ============================================
# EARTH STAFF SPECIFIC
# ============================================
const PROJECTILE_SCENE_PATH = preload("res://Scenes/Spells/BasicProjectile.tscn")

# Earthquake skill settings
const EARTHQUAKE_RADIUS: float = 250.0
const EARTHQUAKE_DAMAGE: float = 40.0
const EARTHQUAKE_SPIKES: int = 8
const SPIKE_DELAY: float = 0.08

func _weapon_ready():
	projectile_scene = PROJECTILE_SCENE_PATH

	# Earth Staff - slower but heavy hitting boulders
	attack_cooldown = 0.45  # Slow, heavy projectiles
	projectile_spread = 3.0  # More accurate
	multi_shot = 1
	damage = 16.0  # High damage boulders
	damage_type = DamageTypes.Type.PHYSICAL

	staff_color = Color(0.45, 0.35, 0.2)  # Dark wood with earth crystal
	muzzle_flash_color = EARTH_GLOW

	# Attack Speed Limits (slow heavy staff)
	max_attacks_per_second = 2.2
	min_cooldown = 0.35

	# Skill settings
	skill_cooldown = 12.0
	beam_damage = 0.0  # Not using beam

func _weapon_process(_delta):
	# Ambient rock dust particles
	if randf() > 0.97:
		_spawn_dust_particle()

func _spawn_dust_particle():
	var dust = ColorRect.new()
	dust.size = Vector2(3, 3)
	dust.color = Color(EARTH_LIGHT.r, EARTH_LIGHT.g, EARTH_LIGHT.b, 0.5)
	dust.pivot_offset = Vector2(1.5, 1.5)
	add_child(dust)
	dust.position = Vector2(randf_range(-8, 8), randf_range(-25, -15))

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(dust, "position:y", dust.position.y + 15, 0.5)
	tween.tween_property(dust, "modulate:a", 0.0, 0.5)
	tween.tween_callback(dust.queue_free)

func _perform_skill() -> bool:
	# METEOR STRIKE - summon a giant meteor from the sky
	if not player_reference:
		return false

	_execute_meteor_strike()
	_play_skill_animation()
	return true

func _execute_meteor_strike():
	var player = player_reference
	if not is_instance_valid(player):
		return

	var target_pos = player.get_global_mouse_position()

	# Show skill text
	_create_meteor_text(player.global_position)

	# Warning circle on ground
	_create_meteor_warning(target_pos)

	# Wait for warning
	await get_tree().create_timer(0.5).timeout

	if not is_instance_valid(self) or not is_instance_valid(player):
		return

	# METEOR FALLS!
	_create_falling_meteor(target_pos)

	# Wait for impact
	await get_tree().create_timer(0.4).timeout

	if not is_instance_valid(self) or not is_instance_valid(player):
		return

	# IMPACT!
	_meteor_impact(target_pos, player)

	# Screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(1.0)

func _create_meteor_text(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	var label = Label.new()
	label.text = "METEOR STRIKE!"
	label.add_theme_font_size_override("font_size", 32)
	label.modulate = EARTH_GLOW
	scene.add_child(label)
	label.global_position = pos + Vector2(-110, -80)

	var tween = TweenHelper.new_tween()
	tween.tween_property(label, "global_position:y", pos.y - 140, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)

func _create_meteor_warning(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Pulsing warning circle
	var warning = ColorRect.new()
	warning.size = Vector2(200, 200)
	warning.color = Color(EARTH_GLOW.r, EARTH_GLOW.g, EARTH_GLOW.b, 0.3)
	warning.pivot_offset = Vector2(100, 100)
	warning.global_position = pos - Vector2(100, 100)
	scene.add_child(warning)

	# Pulsing animation
	var tween = TweenHelper.new_tween()
	tween.tween_property(warning, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(warning, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_property(warning, "modulate:a", 0.8, 0.1)
	tween.tween_callback(warning.queue_free)

func _create_falling_meteor(target_pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Start position (top right of target)
	var start_pos = target_pos + Vector2(400, -500)

	# Create meteor
	var meteor = Node2D.new()
	meteor.global_position = start_pos
	scene.add_child(meteor)

	# Meteor core
	var core = ColorRect.new()
	core.size = Vector2(80, 80)
	core.color = EARTH_CORE
	core.pivot_offset = Vector2(40, 40)
	core.position = Vector2(-40, -40)
	meteor.add_child(core)

	# Hot glow
	var glow = ColorRect.new()
	glow.size = Vector2(100, 100)
	glow.color = Color(1.0, 0.5, 0.2, 0.7)
	glow.pivot_offset = Vector2(50, 50)
	glow.position = Vector2(-50, -50)
	glow.z_index = -1
	meteor.add_child(glow)

	# Fire trail
	_create_meteor_trail(meteor, target_pos)

	# Meteor falls
	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(meteor, "global_position", target_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(meteor, "rotation", TAU, 0.4)
	tween.tween_property(meteor, "scale", Vector2(1.5, 1.5), 0.4)

	await tween.finished

	if is_instance_valid(meteor):
		meteor.queue_free()

func _create_meteor_trail(meteor: Node2D, _target: Vector2):
	# Spawn trail particles while falling
	for i in range(15):
		var delay = i * 0.025
		var meteor_ref = weakref(meteor)
		var staff_ref = weakref(self)

		var timer = get_tree().create_timer(delay)
		timer.timeout.connect(func():
			var m = meteor_ref.get_ref()
			var s = staff_ref.get_ref()
			if m and is_instance_valid(m) and s and is_instance_valid(s):
				s._spawn_trail_particle(m.global_position)
		)

func _spawn_trail_particle(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	var particle = ColorRect.new()
	particle.size = Vector2(randf_range(15, 30), randf_range(15, 30))
	particle.color = Color(1.0, randf_range(0.3, 0.6), 0.1, 0.9)
	particle.pivot_offset = particle.size / 2
	scene.add_child(particle)
	particle.global_position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(particle, "scale", Vector2(0.2, 0.2), 0.3)
	tween.tween_property(particle, "modulate:a", 0.0, 0.3)
	tween.tween_callback(particle.queue_free)

func _meteor_impact(pos: Vector2, player: Node2D):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Giant explosion flash
	var flash = ColorRect.new()
	flash.size = Vector2(300, 300)
	flash.color = Color(1.0, 0.8, 0.4, 0.9)
	flash.pivot_offset = Vector2(150, 150)
	flash.global_position = pos - Vector2(150, 150)
	flash.z_index = 100
	scene.add_child(flash)

	var flash_tween = TweenHelper.new_tween()
	flash_tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.15)
	flash_tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.15)
	flash_tween.tween_callback(flash.queue_free)

	# Debris explosion
	for i in range(20):
		var debris = ColorRect.new()
		debris.size = Vector2(randf_range(15, 35), randf_range(15, 35))
		debris.color = EARTH_CORE if randf() > 0.5 else Color(1.0, 0.5, 0.2)
		debris.pivot_offset = debris.size / 2
		scene.add_child(debris)
		debris.global_position = pos

		var angle = randf() * TAU
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(100, 250)
		var end_pos = pos + dir * dist

		var d_tween = TweenHelper.new_tween()
		d_tween.set_parallel(true)
		d_tween.tween_property(debris, "global_position", end_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		d_tween.tween_property(debris, "global_position:y", end_pos.y + 100, 0.5).set_delay(0.25)
		d_tween.tween_property(debris, "rotation", randf_range(-TAU, TAU), 0.5)
		d_tween.tween_property(debris, "modulate:a", 0.0, 0.5)
		d_tween.tween_callback(debris.queue_free)

	# Crater ring effect
	for ring in range(3):
		var crater = ColorRect.new()
		crater.size = Vector2(100, 100)
		crater.color = Color(EARTH_DARK.r, EARTH_DARK.g, EARTH_DARK.b, 0.6 - ring * 0.15)
		crater.pivot_offset = Vector2(50, 50)
		crater.global_position = pos - Vector2(50, 50)
		scene.add_child(crater)

		var c_tween = TweenHelper.new_tween()
		c_tween.tween_property(crater, "scale", Vector2(3.0 + ring, 3.0 + ring), 0.4).set_delay(ring * 0.1)
		c_tween.tween_property(crater, "modulate:a", 0.0, 0.3)
		c_tween.tween_callback(crater.queue_free)

	# Damage enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
			continue

		var dist = enemy.global_position.distance_to(pos)
		if dist < 200.0:
			var meteor_damage = 80.0 * damage_multiplier
			if is_instance_valid(player) and player.stats:
				meteor_damage *= player.stats.magic_damage_multiplier

			var falloff = 1.0 - (dist / 200.0) * 0.5
			meteor_damage *= falloff

			if enemy.has_method("take_damage"):
				enemy.take_damage(meteor_damage, pos, 700.0, 0.4, player, damage_type)

func _spawn_rock_spike(pos: Vector2, player: Node2D):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Create spike visual
	var spike = Node2D.new()
	spike.global_position = pos
	scene.add_child(spike)

	# Main spike body
	var spike_body = ColorRect.new()
	spike_body.size = Vector2(20, 60)
	spike_body.color = EARTH_CORE
	spike_body.pivot_offset = Vector2(10, 60)  # Pivot at bottom
	spike_body.position = Vector2(-10, 0)
	spike.add_child(spike_body)

	# Spike tip (triangle effect with narrower top)
	var spike_tip = ColorRect.new()
	spike_tip.size = Vector2(14, 25)
	spike_tip.color = EARTH_LIGHT
	spike_tip.pivot_offset = Vector2(7, 25)
	spike_tip.position = Vector2(-7, -60)
	spike.add_child(spike_tip)

	# Debris at base
	for j in range(3):
		var debris = ColorRect.new()
		debris.size = Vector2(randf_range(8, 14), randf_range(6, 10))
		debris.color = EARTH_DARK
		debris.pivot_offset = debris.size / 2
		debris.position = Vector2(randf_range(-25, 25), randf_range(-5, 5))
		spike.add_child(debris)

	# Animation - spike emerges from ground
	spike.scale = Vector2(1.0, 0.0)

	var tween = TweenHelper.new_tween()
	tween.tween_property(spike, "scale:y", 1.2, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(spike, "scale:y", 1.0, 0.05)

	# Damage enemies in range
	tween.tween_callback(func():
		_damage_enemies_at_spike(pos, player)
	)

	# Hold briefly then retract
	tween.tween_interval(0.3)
	tween.tween_property(spike, "scale:y", 0.0, 0.2)
	tween.tween_callback(spike.queue_free)

func _damage_enemies_at_spike(pos: Vector2, player: Node2D):
	var spike_radius: float = 50.0
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.is_in_group("converted_minion"):
			continue

		var dist = enemy.global_position.distance_to(pos)
		if dist <= spike_radius:
			var final_damage = EARTHQUAKE_DAMAGE * damage_multiplier
			if is_instance_valid(player) and player.stats:
				final_damage *= player.stats.magic_damage_multiplier

			if enemy.has_method("take_damage"):
				enemy.take_damage(final_damage, pos, 500.0, 0.25, player, damage_type)
				_create_spike_hit_effect(enemy.global_position)

func _create_spike_hit_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Rock debris burst
	for i in range(5):
		var debris = ColorRect.new()
		debris.size = Vector2(randf_range(6, 12), randf_range(6, 12))
		debris.color = EARTH_CORE
		debris.pivot_offset = debris.size / 2
		scene.add_child(debris)
		debris.global_position = pos

		var angle = randf() * TAU
		var dir = Vector2.from_angle(angle)
		var end_pos = pos + dir * randf_range(30, 60)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(debris, "global_position", end_pos, 0.2)
		tween.tween_property(debris, "rotation", randf_range(-TAU, TAU), 0.2)
		tween.tween_property(debris, "modulate:a", 0.0, 0.2)
		tween.tween_callback(debris.queue_free)

func _create_ground_crack(center: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Radial crack lines
	for i in range(12):
		var crack = ColorRect.new()
		crack.size = Vector2(randf_range(80, 150), 4)
		crack.color = Color(0.25, 0.2, 0.15, 0.8)
		crack.pivot_offset = Vector2(0, 2)
		crack.global_position = center
		crack.rotation = (TAU / 12) * i + randf_range(-0.1, 0.1)
		scene.add_child(crack)

		# Animate crack spreading
		crack.scale = Vector2(0.0, 1.0)

		var tween = TweenHelper.new_tween()
		tween.tween_property(crack, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(crack, "modulate:a", 0.0, 0.8)
		tween.tween_callback(crack.queue_free)

	# Central impact flash
	var flash = ColorRect.new()
	flash.size = Vector2(80, 80)
	flash.color = EARTH_GLOW
	flash.pivot_offset = Vector2(40, 40)
	flash.global_position = center - Vector2(40, 40)
	scene.add_child(flash)

	var flash_tween = TweenHelper.new_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.15)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	flash_tween.tween_callback(flash.queue_free)

func _play_skill_animation():
	# Staff glow brown during skill
	var original_color = sprite.color
	sprite.color = EARTH_GLOW

	# Strong recoil
	var recoil_tween = TweenHelper.new_tween()
	recoil_tween.tween_property(self, "position:x", -25, 0.1)
	recoil_tween.tween_property(self, "position:x", 0, 0.25)

	# Muzzle flash
	muzzle_flash.modulate = Color(EARTH_GLOW.r, EARTH_GLOW.g, EARTH_GLOW.b, 1.0)
	var flash_tween = TweenHelper.new_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.2)

	# Return to normal color
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(self) and sprite:
		sprite.color = original_color

func _get_projectile_color() -> Color:
	return EARTH_CORE

func _get_beam_color() -> Color:
	return EARTH_GLOW

func _get_beam_glow_color() -> Color:
	return EARTH_DARK

# Trail colors - Earthy brown with dust
func _get_trail_color() -> Color:
	return Color(0.55, 0.45, 0.3, 0.85)

func _get_trail_glow_color() -> Color:
	return Color(0.7, 0.6, 0.4, 1.0)

func _get_trail_glow_intensity() -> float:
	return 1.3  # Subtle earthy glow

func _get_trail_pulse_speed() -> float:
	return 2.0  # Slow, steady

func _get_trail_sparkle_amount() -> float:
	return 0.1  # Minimal sparkle, more solid

func _customize_projectile(projectile: Node2D):
	# Boulder projectile - chunky rock
	if projectile.has_node("Sprite"):
		var sprite_node = projectile.get_node("Sprite")
		sprite_node.color = EARTH_CORE
		sprite_node.size = Vector2(22, 22)  # Larger, chunky

	# Slower, heavier projectile
	if projectile.has_method("set") and "speed" in projectile:
		projectile.speed = 600.0  # Slower than default

	# Add rock debris trail
	_add_rock_trail(projectile)

func _add_rock_trail(projectile: Node2D):
	var timer = Timer.new()
	timer.wait_time = 0.06
	timer.one_shot = false
	projectile.add_child(timer)

	var staff_ref = weakref(self)
	var projectile_ref = weakref(projectile)
	var timer_ref = weakref(timer)

	timer.timeout.connect(func():
		var t = timer_ref.get_ref()
		var p = projectile_ref.get_ref()
		var staff = staff_ref.get_ref()

		if not t or not p or not is_instance_valid(p):
			if t and is_instance_valid(t):
				t.stop()
			return

		if not staff or not is_instance_valid(staff):
			if t and is_instance_valid(t):
				t.stop()
			return

		var tree = staff.get_tree()
		if not tree or not tree.current_scene:
			return

		# Rock chunk particle
		var chunk = ColorRect.new()
		chunk.size = Vector2(randf_range(6, 10), randf_range(6, 10))
		var color_choice = randf()
		if color_choice > 0.5:
			chunk.color = EARTH_CORE
		else:
			chunk.color = EARTH_DARK
		chunk.pivot_offset = chunk.size / 2
		chunk.z_index = 99
		tree.current_scene.add_child(chunk)
		chunk.global_position = p.global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))

		# Chunks fall and fade
		var end_y = chunk.global_position.y + randf_range(15, 30)
		var tween = tree.create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(chunk, "global_position:y", end_y, 0.3)
			tween.tween_property(chunk, "rotation", randf_range(-PI, PI), 0.3)
			tween.tween_property(chunk, "modulate:a", 0.0, 0.3)
			tween.tween_callback(chunk.queue_free)
	)
	timer.start()
