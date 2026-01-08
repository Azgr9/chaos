# SCRIPT: HolyStaff.gd
# ATTACH TO: HolyStaff (Node2D) root node in HolyStaff.tscn
# LOCATION: res://Scripts/Weapons/HolyStaff.gd
# Holy/light themed staff with Divine Judgement skill

class_name HolyStaff
extends MagicWeapon

# ============================================
# PROJECTILE COLORS
# ============================================
const HOLY_CORE: Color = Color(1.0, 1.0, 0.9)  # Bright white-yellow
const HOLY_GLOW: Color = Color(1.0, 0.95, 0.7)  # Warm golden
const HOLY_OUTER: Color = Color(0.9, 0.85, 0.6, 0.7)  # Soft gold
const DIVINE_COLOR: Color = Color(1.0, 0.9, 0.5)  # Divine gold
const HALO_COLOR: Color = Color(1.0, 1.0, 0.85, 0.5)  # Halo effect

# ============================================
# HOLY STAFF SPECIFIC
# ============================================
const PROJECTILE_SCENE_PATH = preload("res://Scenes/Spells/BasicProjectile.tscn")

# DIVINE STORM skill settings
const STORM_RADIUS: float = 250.0  # Total area of divine storm
const STORM_DAMAGE: float = 40.0  # Damage per lightning strike
const LIGHTNING_COUNT: int = 12  # Number of lightning bolts
const STORM_DURATION: float = 1.5  # How long the storm lasts

# Healing aura (passive)
var heal_timer: float = 0.0
const HEAL_INTERVAL: float = 3.0
const HEAL_AMOUNT: float = 2.0

func _weapon_ready():
	projectile_scene = PROJECTILE_SCENE_PATH

	# Holy Staff - fast light projectiles
	attack_cooldown = 0.25  # Fast casting
	projectile_spread = 4.0
	multi_shot = 1
	damage = 9.0  # Lower damage but fast + utility
	damage_type = DamageTypes.Type.PHYSICAL  # Holy damage (no special type yet)

	staff_color = Color(0.95, 0.9, 0.8)  # White-gold staff
	muzzle_flash_color = HOLY_GLOW

	# Attack Speed Limits (fast holy staff)
	max_attacks_per_second = 4.0
	min_cooldown = 0.18

	# Skill settings
	skill_cooldown = 14.0
	beam_damage = 0.0  # Not using beam

func _weapon_process(delta):
	# Ambient holy particles
	if randf() > 0.96:
		_spawn_holy_particle()

	# Passive healing aura
	heal_timer += delta
	if heal_timer >= HEAL_INTERVAL:
		heal_timer = 0.0
		_apply_healing_aura()

func _spawn_holy_particle():
	var particle = ColorRect.new()
	particle.size = Vector2(4, 4)
	particle.color = HOLY_GLOW
	particle.pivot_offset = Vector2(2, 2)
	add_child(particle)
	particle.position = Vector2(randf_range(-10, 10), randf_range(-30, -15))

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(particle, "position:y", particle.position.y - 25, 0.6)
	tween.tween_property(particle, "scale", Vector2(0.3, 0.3), 0.6)
	tween.tween_property(particle, "modulate:a", 0.0, 0.6)
	tween.tween_callback(particle.queue_free)

func _apply_healing_aura():
	if not player_reference or not is_instance_valid(player_reference):
		return

	# Small heal over time
	if player_reference.has_method("heal"):
		player_reference.heal(HEAL_AMOUNT)
		_create_heal_effect()

func _create_heal_effect():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Small sparkle effect on player
	for i in range(3):
		var sparkle = ColorRect.new()
		sparkle.size = Vector2(6, 6)
		sparkle.color = HOLY_GLOW
		sparkle.pivot_offset = Vector2(3, 3)
		scene.add_child(sparkle)
		sparkle.global_position = player_reference.global_position + Vector2(randf_range(-20, 20), randf_range(-30, 0))

		var angle = randf_range(-PI * 0.8, -PI * 0.2)
		var end_pos = sparkle.global_position + Vector2.from_angle(angle) * 30

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(sparkle, "global_position", end_pos, 0.4)
		tween.tween_property(sparkle, "modulate:a", 0.0, 0.4)
		tween.tween_callback(sparkle.queue_free)

func _perform_skill() -> bool:
	# DIVINE STORM - Massive holy storm from the heavens!
	if not player_reference:
		return false

	_execute_divine_storm()
	_play_skill_animation()
	return true

func _execute_divine_storm():
	var player = player_reference
	if not is_instance_valid(player):
		return

	var self_ref = weakref(self)
	var player_ref = weakref(player)
	var target_pos = player.get_global_mouse_position()

	var scene = get_tree().current_scene
	if not scene:
		return

	# Create massive holy circle on ground
	_create_storm_circle(target_pos, scene)

	# Build-up - light gathering from above
	_create_storm_buildup(target_pos, scene)

	# Screen shake
	DamageNumberManager.shake(0.5)

	var tree = get_tree()
	if not tree:
		return
	await tree.create_timer(0.4).timeout

	if not self_ref.get_ref() or not player_ref.get_ref():
		return

	# INITIAL BLAST - massive light explosion from sky
	_create_divine_blast(target_pos, scene, player_ref)

	# Rain down lightning bolts
	var interval = STORM_DURATION / LIGHTNING_COUNT
	for i in range(LIGHTNING_COUNT):
		if not self_ref.get_ref():
			break

		# Random position within storm radius
		var offset = Vector2(
			randf_range(-STORM_RADIUS, STORM_RADIUS),
			randf_range(-STORM_RADIUS, STORM_RADIUS)
		)
		var bolt_pos = target_pos + offset

		_spawn_lightning_bolt(bolt_pos, scene, player_ref)

		tree = get_tree()
		if not tree:
			break
		await tree.create_timer(interval).timeout

	# Final divine explosion
	if self_ref.get_ref() and player_ref.get_ref():
		_create_final_divine_explosion(target_pos, scene, player_ref)

func _create_storm_circle(pos: Vector2, scene: Node):
	# Large holy circle on ground
	var circle = ColorRect.new()
	circle.size = Vector2(STORM_RADIUS * 2, STORM_RADIUS * 2)
	circle.pivot_offset = Vector2(STORM_RADIUS, STORM_RADIUS)
	circle.position = pos - Vector2(STORM_RADIUS, STORM_RADIUS)
	circle.color = Color(DIVINE_COLOR.r, DIVINE_COLOR.g, DIVINE_COLOR.b, 0.3)
	scene.add_child(circle)

	var tween = TweenHelper.new_tween()
	tween.tween_property(circle, "modulate:a", 0.6, 0.2)
	tween.tween_property(circle, "modulate:a", 0.2, 0.2)
	tween.set_loops(int(STORM_DURATION / 0.4))
	tween.tween_callback(circle.queue_free)

	# Rotating runes
	for i in range(8):
		var rune = ColorRect.new()
		rune.size = Vector2(30, 30)
		rune.pivot_offset = Vector2(15, 15)
		rune.color = HOLY_GLOW
		scene.add_child(rune)

		var angle = (TAU / 8) * i
		rune.position = pos + Vector2.from_angle(angle) * (STORM_RADIUS * 0.7)
		rune.rotation = angle

		var r_tween = TweenHelper.new_tween()
		r_tween.tween_property(rune, "rotation", angle + TAU, STORM_DURATION)
		r_tween.parallel().tween_property(rune, "modulate:a", 0.0, STORM_DURATION)
		r_tween.tween_callback(rune.queue_free)

func _create_storm_buildup(pos: Vector2, scene: Node):
	# Light rays descending from above
	for i in range(6):
		var ray = ColorRect.new()
		ray.size = Vector2(15, 300)
		ray.pivot_offset = Vector2(7.5, 0)
		ray.color = Color(HOLY_CORE.r, HOLY_CORE.g, HOLY_CORE.b, 0.6)
		scene.add_child(ray)

		var _angle = (TAU / 6) * i  # Used for distribution
		var start = pos + Vector2(randf_range(-100, 100), -400)
		ray.position = start
		ray.rotation = randf_range(-0.3, 0.3)

		var tween = TweenHelper.new_tween()
		tween.tween_property(ray, "position:y", pos.y - 50, 0.35)
		tween.parallel().tween_property(ray, "modulate:a", 0.0, 0.4)
		tween.tween_callback(ray.queue_free)

func _create_divine_blast(pos: Vector2, scene: Node, player_ref: WeakRef):
	# Massive central explosion
	var blast = ColorRect.new()
	blast.size = Vector2(150, 150)
	blast.pivot_offset = Vector2(75, 75)
	blast.position = pos - Vector2(75, 75)
	blast.color = HOLY_CORE
	scene.add_child(blast)

	var tween = TweenHelper.new_tween()
	tween.tween_property(blast, "scale", Vector2(4.0, 4.0), 0.2)
	tween.parallel().tween_property(blast, "modulate:a", 0.0, 0.25)
	tween.tween_callback(blast.queue_free)

	# Light pillars shooting up
	for i in range(8):
		var pillar = ColorRect.new()
		pillar.size = Vector2(20, 200)
		pillar.pivot_offset = Vector2(10, 200)
		pillar.color = HOLY_GLOW

		var angle = (TAU / 8) * i
		var pillar_pos = pos + Vector2.from_angle(angle) * 60
		pillar.position = pillar_pos - Vector2(10, 0)
		scene.add_child(pillar)

		var p_tween = TweenHelper.new_tween()
		p_tween.tween_property(pillar, "position:y", pillar.position.y - 150, 0.2)
		p_tween.parallel().tween_property(pillar, "scale:y", 0.0, 0.3)
		p_tween.tween_property(pillar, "modulate:a", 0.0, 0.1)
		p_tween.tween_callback(pillar.queue_free)

	# Deal damage at center
	var player = player_ref.get_ref()
	if player:
		_damage_enemies_in_radius(pos, STORM_RADIUS * 0.5, STORM_DAMAGE * 1.5, player)

	DamageNumberManager.shake(0.6)

func _spawn_lightning_bolt(pos: Vector2, scene: Node, player_ref: WeakRef):
	# Lightning bolt from sky
	var bolt = Node2D.new()
	bolt.position = pos
	scene.add_child(bolt)

	# Main bolt (jagged line simulated with multiple segments)
	var bolt_height = 350.0
	var segment_count = 8
	var segment_height = bolt_height / segment_count

	var prev_offset = 0.0
	for i in range(segment_count):
		var segment = ColorRect.new()
		var width = 8.0 if i < segment_count - 1 else 15.0
		segment.size = Vector2(width, segment_height + 10)
		segment.pivot_offset = Vector2(width / 2, 0)
		segment.color = HOLY_CORE

		var offset = randf_range(-25, 25) if i < segment_count - 1 else 0.0
		segment.position = Vector2(prev_offset - width / 2, -bolt_height + i * segment_height)
		segment.rotation = atan2(offset - prev_offset, segment_height)
		bolt.add_child(segment)

		prev_offset = offset

	# Glow around bolt
	var glow = ColorRect.new()
	glow.size = Vector2(50, bolt_height)
	glow.pivot_offset = Vector2(25, 0)
	glow.position = Vector2(-25, -bolt_height)
	glow.color = Color(HOLY_GLOW.r, HOLY_GLOW.g, HOLY_GLOW.b, 0.4)
	glow.z_index = -1
	bolt.add_child(glow)

	# Ground impact
	var impact = ColorRect.new()
	impact.size = Vector2(60, 60)
	impact.pivot_offset = Vector2(30, 30)
	impact.position = Vector2(-30, -30)
	impact.color = HOLY_CORE
	bolt.add_child(impact)

	# Animation
	bolt.modulate.a = 0.0
	bolt.scale = Vector2(1.0, 0.0)

	var tween = TweenHelper.new_tween()
	tween.tween_property(bolt, "modulate:a", 1.0, 0.02)
	tween.parallel().tween_property(bolt, "scale:y", 1.0, 0.04)

	# Deal damage
	tween.tween_callback(func():
		var player = player_ref.get_ref()
		if player:
			_damage_enemies_in_radius(pos, 40.0, STORM_DAMAGE, player)
		_create_lightning_impact(pos, scene)
		DamageNumberManager.shake(0.15)
	)

	# Flash brighter
	tween.tween_property(bolt, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.05)

	# Fade
	tween.tween_property(bolt, "modulate:a", 0.0, 0.15)
	tween.tween_callback(bolt.queue_free)

func _create_lightning_impact(pos: Vector2, scene: Node):
	# Small impact burst
	for i in range(4):
		var spark = ColorRect.new()
		spark.size = Vector2(10, 10)
		spark.pivot_offset = Vector2(5, 5)
		spark.color = HOLY_GLOW
		scene.add_child(spark)
		spark.position = pos

		var angle = (TAU / 4) * i + randf_range(-0.3, 0.3)
		var dir = Vector2.from_angle(angle)

		var tween = TweenHelper.new_tween()
		tween.tween_property(spark, "position", pos + dir * 40, 0.1)
		tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.12)
		tween.tween_callback(spark.queue_free)

func _create_final_divine_explosion(pos: Vector2, scene: Node, player_ref: WeakRef):
	# Giant final explosion
	var explosion = ColorRect.new()
	explosion.size = Vector2(200, 200)
	explosion.pivot_offset = Vector2(100, 100)
	explosion.position = pos - Vector2(100, 100)
	explosion.color = DIVINE_COLOR
	scene.add_child(explosion)

	var tween = TweenHelper.new_tween()
	tween.tween_property(explosion, "scale", Vector2(5.0, 5.0), 0.3)
	tween.parallel().tween_property(explosion, "modulate:a", 0.0, 0.35)
	tween.tween_callback(explosion.queue_free)

	# Holy rings expanding
	for i in range(3):
		var ring = ColorRect.new()
		ring.size = Vector2(100, 100)
		ring.pivot_offset = Vector2(50, 50)
		ring.position = pos - Vector2(50, 50)
		ring.color = Color(HOLY_GLOW.r, HOLY_GLOW.g, HOLY_GLOW.b, 0.6 - i * 0.15)
		scene.add_child(ring)

		var r_tween = TweenHelper.new_tween()
		r_tween.set_parallel(true)
		r_tween.tween_property(ring, "scale", Vector2(4.0 + i, 4.0 + i), 0.25 + i * 0.08)
		r_tween.tween_property(ring, "modulate:a", 0.0, 0.3 + i * 0.08)
		r_tween.tween_callback(ring.queue_free)

	# Final damage
	var player = player_ref.get_ref()
	if player:
		_damage_enemies_in_radius(pos, STORM_RADIUS, STORM_DAMAGE * 2.0, player)

	DamageNumberManager.shake(0.8)

func _damage_enemies_in_radius(pos: Vector2, radius: float, dmg: float, player: Node2D):
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
			continue

		var dist = enemy.global_position.distance_to(pos)
		if dist <= radius:
			var final_damage = dmg * damage_multiplier
			if is_instance_valid(player) and player.stats:
				final_damage *= player.stats.magic_damage_multiplier

			if enemy.has_method("take_damage"):
				enemy.take_damage(final_damage, pos, 400.0, 0.2, player, damage_type)
				_create_lightning_hit_effect(enemy.global_position)

func _create_lightning_hit_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	var flash = ColorRect.new()
	flash.size = Vector2(40, 40)
	flash.color = HOLY_CORE
	flash.pivot_offset = Vector2(20, 20)
	scene.add_child(flash)
	flash.global_position = pos - Vector2(20, 20)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2.5, 2.5), 0.1)
	tween.tween_property(flash, "modulate:a", 0.0, 0.12)
	tween.tween_callback(flash.queue_free)

func _play_skill_animation():
	# Staff glow bright during skill
	var original_color = sprite.color
	sprite.color = HOLY_CORE

	# Raise staff
	var recoil_tween = TweenHelper.new_tween()
	recoil_tween.tween_property(self, "position:y", -15, 0.1)
	recoil_tween.tween_property(self, "position:y", 0, 0.2)

	# Muzzle flash
	muzzle_flash.modulate = Color(HOLY_GLOW.r, HOLY_GLOW.g, HOLY_GLOW.b, 1.0)
	var flash_tween = TweenHelper.new_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.3)

	# Return to normal color
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self) and sprite:
		sprite.color = original_color

func _get_projectile_color() -> Color:
	return HOLY_CORE

func _get_beam_color() -> Color:
	return HOLY_GLOW

func _get_beam_glow_color() -> Color:
	return HOLY_OUTER

# Trail colors - Bright holy light
func _get_trail_color() -> Color:
	return Color(1.0, 0.95, 0.8, 0.9)

func _get_trail_glow_color() -> Color:
	return Color(1.0, 1.0, 0.9, 1.0)

func _get_trail_glow_intensity() -> float:
	return 2.0  # Bright holy glow

func _get_trail_pulse_speed() -> float:
	return 5.0  # Gentle pulsing

func _get_trail_sparkle_amount() -> float:
	return 0.5  # Sparkly divine magic

func _customize_projectile(projectile: Node2D):
	# Holy light projectile - bright and glowing
	if projectile.has_node("Sprite"):
		var sprite_node = projectile.get_node("Sprite")
		sprite_node.color = HOLY_CORE
		sprite_node.size = Vector2(14, 14)

	# Fast projectile
	if projectile.has_method("set") and "speed" in projectile:
		projectile.speed = 1200.0  # Faster than default

	# Add holy trail
	_add_holy_trail(projectile)

func _add_holy_trail(projectile: Node2D):
	var timer = Timer.new()
	timer.wait_time = 0.03
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

		# Light sparkle particle
		var sparkle = ColorRect.new()
		sparkle.size = Vector2(6, 6)
		sparkle.color = HOLY_GLOW
		sparkle.pivot_offset = Vector2(3, 3)
		sparkle.z_index = 99
		tree.current_scene.add_child(sparkle)
		sparkle.global_position = p.global_position + Vector2(randf_range(-5, 5), randf_range(-5, 5))

		# Sparkles rise and fade
		var tween = tree.create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(sparkle, "global_position:y", sparkle.global_position.y - 20, 0.25)
			tween.tween_property(sparkle, "scale", Vector2(0.2, 0.2), 0.25)
			tween.tween_property(sparkle, "modulate:a", 0.0, 0.25)
			tween.tween_callback(sparkle.queue_free)
	)
	timer.start()
