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

# Divine Judgement skill settings
const JUDGEMENT_PILLARS: int = 5
const PILLAR_DAMAGE: float = 35.0
const PILLAR_RADIUS: float = 60.0
const PILLAR_DELAY: float = 0.15
const JUDGEMENT_RANGE: float = 300.0

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
	# Divine Judgement - pillars of light from above
	if not player_reference:
		return false

	_execute_divine_judgement()
	_play_skill_animation()
	return true

func _execute_divine_judgement():
	var player = player_reference
	if not is_instance_valid(player):
		return

	# Get direction toward mouse
	var direction = (player.get_global_mouse_position() - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	# Calculate pillar positions in a line toward mouse
	var base_pos = player.global_position

	for i in range(JUDGEMENT_PILLARS):
		var delay = i * PILLAR_DELAY
		var distance = (i + 1) * (JUDGEMENT_RANGE / JUDGEMENT_PILLARS)
		var pillar_pos = base_pos + direction * distance

		# Add slight spread
		pillar_pos += Vector2(randf_range(-30, 30), randf_range(-30, 30))

		var timer = get_tree().create_timer(delay)
		var staff_ref = weakref(self)
		var player_ref = weakref(player)

		timer.timeout.connect(func():
			var s = staff_ref.get_ref()
			var p = player_ref.get_ref()
			if s and is_instance_valid(s):
				s._spawn_light_pillar(pillar_pos, p)
		)

	# Screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.4)

func _spawn_light_pillar(pos: Vector2, player: Node2D):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Warning indicator first
	_create_pillar_warning(pos)

	# Delay then spawn pillar
	await get_tree().create_timer(0.2).timeout

	if not is_instance_valid(self):
		return

	# Create pillar visual
	var pillar = Node2D.new()
	pillar.global_position = pos
	scene.add_child(pillar)

	# Main light beam (vertical rectangle going up)
	var beam = ColorRect.new()
	beam.size = Vector2(40, 400)
	beam.color = HOLY_CORE
	beam.pivot_offset = Vector2(20, 400)  # Pivot at bottom
	beam.position = Vector2(-20, 0)
	pillar.add_child(beam)

	# Outer glow
	var glow = ColorRect.new()
	glow.size = Vector2(60, 400)
	glow.color = Color(HOLY_GLOW.r, HOLY_GLOW.g, HOLY_GLOW.b, 0.5)
	glow.pivot_offset = Vector2(30, 400)
	glow.position = Vector2(-30, 0)
	glow.z_index = -1
	pillar.add_child(glow)

	# Ground circle
	var circle = ColorRect.new()
	circle.size = Vector2(80, 80)
	circle.color = Color(DIVINE_COLOR.r, DIVINE_COLOR.g, DIVINE_COLOR.b, 0.6)
	circle.pivot_offset = Vector2(40, 40)
	circle.position = Vector2(-40, -40)
	pillar.add_child(circle)

	# Animation - pillar descends and expands
	pillar.scale = Vector2(0.3, 0.0)
	pillar.modulate.a = 0.0

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(pillar, "scale", Vector2(1.2, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pillar, "modulate:a", 1.0, 0.1)

	tween.set_parallel(false)

	# Damage enemies
	tween.tween_callback(func():
		_damage_enemies_at_pillar(pos, player)
	)

	# Flash brighter
	tween.tween_property(pillar, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
	tween.tween_property(pillar, "modulate", Color.WHITE, 0.1)

	# Hold briefly
	tween.tween_interval(0.2)

	# Fade out
	tween.tween_property(pillar, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(pillar, "scale:x", 0.1, 0.3)
	tween.tween_callback(pillar.queue_free)

func _create_pillar_warning(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Circular warning indicator
	var warning = ColorRect.new()
	warning.size = Vector2(60, 60)
	warning.color = Color(DIVINE_COLOR.r, DIVINE_COLOR.g, DIVINE_COLOR.b, 0.3)
	warning.pivot_offset = Vector2(30, 30)
	warning.global_position = pos - Vector2(30, 30)
	scene.add_child(warning)

	var tween = TweenHelper.new_tween()
	tween.tween_property(warning, "scale", Vector2(1.5, 1.5), 0.2)
	tween.parallel().tween_property(warning, "modulate:a", 0.8, 0.1)
	tween.tween_property(warning, "modulate:a", 0.0, 0.1)
	tween.tween_callback(warning.queue_free)

func _damage_enemies_at_pillar(pos: Vector2, player: Node2D):
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.is_in_group("converted_minion"):
			continue

		var dist = enemy.global_position.distance_to(pos)
		if dist <= PILLAR_RADIUS:
			var final_damage = PILLAR_DAMAGE * damage_multiplier
			if is_instance_valid(player) and player.stats:
				final_damage *= player.stats.magic_damage_multiplier

			if enemy.has_method("take_damage"):
				enemy.take_damage(final_damage, pos, 350.0, 0.2, player, damage_type)
				_create_pillar_hit_effect(enemy.global_position)

func _create_pillar_hit_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Holy burst
	for i in range(6):
		var spark = ColorRect.new()
		spark.size = Vector2(8, 16)
		spark.color = HOLY_GLOW
		spark.pivot_offset = Vector2(4, 8)
		scene.add_child(spark)
		spark.global_position = pos

		var angle = (TAU / 6) * i
		var dir = Vector2.from_angle(angle)
		spark.rotation = angle + PI / 2

		var end_pos = pos + dir * randf_range(40, 70)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", end_pos, 0.15)
		tween.tween_property(spark, "scale", Vector2(0.3, 0.3), 0.15)
		tween.tween_property(spark, "modulate:a", 0.0, 0.15)
		tween.tween_callback(spark.queue_free)

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
