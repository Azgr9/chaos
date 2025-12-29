# SCRIPT: InfernoStaff.gd
# ATTACH TO: InfernoStaff (Node2D) root node in InfernoStaff.tscn
# LOCATION: res://Scripts/Weapons/InfernoStaff.gd
# AoE/DoT staff that creates burning zones - affects enemies AND player (risk/reward)

class_name InfernoStaff
extends MagicWeapon

# ============================================
# PROJECTILE COLORS
# ============================================
const FIRE_CORE: Color = Color(1.0, 0.8, 0.2)  # Bright yellow-orange core
const FIRE_MID: Color = Color(1.0, 0.4, 0.1)  # Orange
const FIRE_OUTER: Color = Color(0.8, 0.2, 0.0, 0.7)  # Dark red outer
const EMBER_COLOR: Color = Color(1.0, 0.5, 0.0)  # Ember particles

# ============================================
# INFERNO STAFF SPECIFIC
# ============================================
const FIRE_ZONE_SCENE = preload("res://Scenes/Spells/FireZone.tscn")

# Volcano Eruption settings
var volcano_radius: float = 150.0  # Larger explosion radius
var volcano_damage: float = 35.0  # Initial burst damage
var lava_pool_damage: float = 10.0  # Damage per second in lava
var lava_pool_duration: float = 4.0  # How long lava persists
var fire_immunity_duration: float = 3.0  # Fire immunity lasts this long

# Visual colors
const LAVA_CORE: Color = Color(1.0, 0.6, 0.0)  # Bright orange-yellow
const LAVA_OUTER: Color = Color(0.8, 0.2, 0.0, 0.8)  # Dark red
const MAGMA_COLOR: Color = Color(1.0, 0.3, 0.0)  # Red-orange

func _weapon_ready():
	# Inferno Staff - slower but higher damage fireballs
	attack_cooldown = 0.38  # Slower, heavier fireballs
	projectile_spread = 8.0
	multi_shot = 1
	damage = 14.0  # Higher base damage for slower speed
	damage_type = DamageTypes.Type.FIRE  # Applies BURN status effect

	staff_color = Color("#8b0000")  # Dark red crystal staff
	muzzle_flash_color = Color(1.0, 0.5, 0.1)  # Orange flash

	# Attack Speed Limits (slower, higher damage staff)
	max_attacks_per_second = 2.5  # Slower but powerful
	min_cooldown = 0.28  # Cannot cast faster than this

	# Skill settings - Volcano Eruption
	skill_cooldown = 10.0  # Powerful skill needs longer cooldown
	beam_damage = 0.0  # Not using beam

func _weapon_process(_delta):
	# Ambient fire particle on staff
	if randf() > 0.95:
		_spawn_staff_ember()

func _spawn_staff_ember():
	var ember = ColorRect.new()
	ember.size = Vector2(4, 6)
	ember.color = EMBER_COLOR
	ember.pivot_offset = Vector2(2, 3)
	add_child(ember)
	ember.position = Vector2(randf_range(-5, 5), randf_range(-20, -10))

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(ember, "position:y", ember.position.y - 20, 0.4)
	tween.tween_property(ember, "modulate:a", 0.0, 0.4)
	tween.tween_callback(ember.queue_free)

func _perform_skill() -> bool:
	# Volcano Eruption - explosion at player position with fire immunity
	if not player_reference:
		return false

	var player_pos = player_reference.global_position

	# Grant fire immunity FIRST
	_grant_fire_immunity()

	# Create volcano eruption effect
	_create_volcano_eruption(player_pos)

	# Deal burst damage to all enemies in radius
	_deal_eruption_damage(player_pos)

	# Create persistent lava pool
	_create_lava_pool(player_pos)

	# Visual feedback on staff
	_play_skill_animation()

	return true

func _grant_fire_immunity():
	if not player_reference:
		return

	# Grant actual fire immunity
	player_reference.is_fire_immune = true

	# Visual indicator - player glows orange
	player_reference.modulate = Color(1.0, 0.7, 0.4)

	# Create fire aura around player
	_create_fire_aura()

	# Timer to remove immunity
	_remove_fire_immunity_delayed()

func _remove_fire_immunity_delayed():
	await get_tree().create_timer(fire_immunity_duration).timeout
	if is_instance_valid(player_reference):
		player_reference.is_fire_immune = false
		player_reference.modulate = Color.WHITE

func _create_fire_aura():
	if not player_reference:
		return

	# Create particles that orbit around player during immunity
	var aura_container = Node2D.new()
	player_reference.add_child(aura_container)

	# Spawn orbiting embers
	for i in range(8):
		var ember = ColorRect.new()
		ember.size = Vector2(8, 12)
		ember.color = FIRE_CORE
		ember.pivot_offset = Vector2(4, 6)
		aura_container.add_child(ember)

		var angle = (TAU / 8) * i
		ember.position = Vector2.from_angle(angle) * 40

	# Animate the aura
	_animate_fire_aura(aura_container)

func _animate_fire_aura(aura: Node2D):
	var elapsed = 0.0
	while elapsed < fire_immunity_duration:
		if not is_instance_valid(aura):
			break

		var delta = get_process_delta_time()
		elapsed += delta

		# Rotate the aura
		aura.rotation += delta * 3.0

		# Update ember positions with wobble
		var children = aura.get_children()
		for i in range(children.size()):
			var ember = children[i]
			if is_instance_valid(ember):
				var base_angle = (TAU / children.size()) * i + aura.rotation
				var radius = 35 + sin(elapsed * 5.0 + i) * 8
				ember.position = Vector2.from_angle(base_angle) * radius
				ember.color = FIRE_CORE.lerp(FIRE_MID, (sin(elapsed * 8.0 + i) + 1) / 2)

		# Fade out near end
		if elapsed > fire_immunity_duration - 0.5:
			aura.modulate.a = (fire_immunity_duration - elapsed) / 0.5

		await get_tree().process_frame

	if is_instance_valid(aura):
		aura.queue_free()

func _create_volcano_eruption(center: Vector2):
	# Initial explosion flash
	var flash = ColorRect.new()
	flash.size = Vector2(volcano_radius * 2.5, volcano_radius * 2.5)
	flash.color = FIRE_CORE
	flash.pivot_offset = flash.size / 2
	get_tree().current_scene.add_child(flash)
	flash.global_position = center

	var flash_tween = TweenHelper.new_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(1.5, 1.5), 0.15)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	flash_tween.tween_callback(flash.queue_free)

	# Create multiple shockwave rings
	for i in range(3):
		_create_eruption_ring(center, i * 0.08, volcano_radius * (0.5 + i * 0.3))

	# Spawn erupting fire/magma particles shooting outward
	for i in range(30):
		_spawn_eruption_particle(center)

	# Screen shake
	DamageNumberManager.shake(0.7)

func _create_eruption_ring(center: Vector2, delay: float, radius: float):
	await get_tree().create_timer(delay).timeout

	if not is_instance_valid(self):
		return

	var ring = ColorRect.new()
	ring.size = Vector2(radius * 2, radius * 2)
	ring.color = LAVA_OUTER
	ring.pivot_offset = Vector2(radius, radius)
	get_tree().current_scene.add_child(ring)
	ring.global_position = center
	ring.scale = Vector2(0.3, 0.3)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ring.queue_free)

func _spawn_eruption_particle(center: Vector2):
	var particle = ColorRect.new()
	particle.size = Vector2(randf_range(12, 24), randf_range(16, 32))
	particle.pivot_offset = particle.size / 2

	# Random fire color
	var color_roll = randf()
	if color_roll > 0.6:
		particle.color = FIRE_CORE
	elif color_roll > 0.3:
		particle.color = FIRE_MID
	else:
		particle.color = MAGMA_COLOR

	get_tree().current_scene.add_child(particle)
	particle.global_position = center

	# Launch in random direction with arc
	var angle = randf() * TAU
	var direction = Vector2.from_angle(angle)
	var target_pos = center + direction * randf_range(80, volcano_radius * 1.2)

	# Arc upward then fall
	var peak_height = randf_range(50, 120)
	var duration = randf_range(0.4, 0.7)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)

	# Horizontal movement
	tween.tween_property(particle, "global_position:x", target_pos.x, duration)

	# Vertical arc - go up then down
	var start_y = center.y
	tween.tween_property(particle, "global_position:y", start_y - peak_height, duration * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(particle, "global_position:y", target_pos.y, duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Rotate as it flies
	tween.tween_property(particle, "rotation", randf_range(-TAU, TAU), duration)

	# Fade and shrink at end
	tween.tween_property(particle, "modulate:a", 0.0, duration)
	tween.tween_property(particle, "scale", Vector2(0.3, 0.3), duration)
	tween.tween_callback(particle.queue_free)

func _deal_eruption_damage(center: Vector2):
	var enemies = _get_enemies()
	var magic_mult = player_reference.stats.magic_damage_multiplier if player_reference else 1.0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var dist = enemy.global_position.distance_to(center)
		if dist <= volcano_radius:
			# Full damage at center, less at edge
			var damage_falloff = 1.0 - (dist / volcano_radius) * 0.5
			var final_damage = volcano_damage * magic_mult * damage_falloff

			if enemy.has_method("take_damage"):
				var attacker = player_reference if is_instance_valid(player_reference) else null
				enemy.take_damage(final_damage, center, 400.0, 0.2, attacker, damage_type)

			# Create hit effect
			_create_eruption_hit(enemy.global_position)

func _create_eruption_hit(pos: Vector2):
	var hit = ColorRect.new()
	hit.size = Vector2(40, 40)
	hit.color = FIRE_CORE
	hit.pivot_offset = Vector2(20, 20)
	get_tree().current_scene.add_child(hit)
	hit.global_position = pos

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(hit, "scale", Vector2(2, 2), 0.2)
	tween.tween_property(hit, "modulate:a", 0.0, 0.2)
	tween.tween_callback(hit.queue_free)

func _create_lava_pool(center: Vector2):
	# Create fire zone using existing system
	var fire_zone = FIRE_ZONE_SCENE.instantiate()
	get_tree().current_scene.add_child(fire_zone)

	var magic_mult = player_reference.stats.magic_damage_multiplier if player_reference else 1.0

	fire_zone.initialize(
		center,
		lava_pool_damage * magic_mult,
		lava_pool_duration,
		volcano_radius * 0.8,  # Slightly smaller than eruption radius
		player_reference
	)

	# Add bubbling lava effect on top
	_animate_lava_bubbles(center, lava_pool_duration)

func _play_skill_animation():
	# Staff glow red during skill
	var original_color = sprite.color
	sprite.color = Color(1.0, 0.3, 0.1)

	# Recoil
	var recoil_tween = TweenHelper.new_tween()
	recoil_tween.tween_property(self, "position:x", -20, 0.1)
	recoil_tween.tween_property(self, "position:x", 0, 0.2)

	# Muzzle flash
	muzzle_flash.modulate = Color(1.0, 0.5, 0.1, 1.0)
	var flash_tween = TweenHelper.new_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.2)

	# Return to normal color
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(self) and sprite:
		sprite.color = original_color

func _get_projectile_color() -> Color:
	return FIRE_CORE

func _get_beam_color() -> Color:
	return Color(1.0, 0.5, 0.1, 1.0)  # Bright orange

func _get_beam_glow_color() -> Color:
	return FIRE_OUTER

func _customize_projectile(projectile: Node2D):
	# Blazing fireball projectile
	if projectile.has_node("Sprite"):
		var sprite_node = projectile.get_node("Sprite")
		sprite_node.color = FIRE_CORE
		sprite_node.size = Vector2(18, 18)  # Round fireball

	# Add flame trail effect
	_add_flame_trail(projectile)

func _add_flame_trail(projectile: Node2D):
	var timer = Timer.new()
	timer.wait_time = 0.025
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
		if not staff or not is_instance_valid(staff):
			timer.stop()
			timer.queue_free()
			return

		# Ensure staff is in tree
		var tree = staff.get_tree()
		if not tree or not tree.current_scene:
			timer.stop()
			timer.queue_free()
			return

		# Flame particle
		var flame = ColorRect.new()
		flame.size = Vector2(randf_range(10, 16), randf_range(14, 22))
		# Gradient from yellow core to orange to red
		var color_choice = randf()
		if color_choice > 0.7:
			flame.color = FIRE_CORE
		elif color_choice > 0.3:
			flame.color = FIRE_MID
		else:
			flame.color = FIRE_OUTER
		flame.pivot_offset = flame.size / 2
		tree.current_scene.add_child(flame)
		flame.global_position = projectile.global_position + Vector2(randf_range(-6, 6), randf_range(-6, 6))

		# Flames rise and fade
		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(flame, "global_position:y", flame.global_position.y - randf_range(15, 30), 0.25)
		tween.tween_property(flame, "scale", Vector2(0.2, 0.4), 0.25)
		tween.tween_property(flame, "modulate:a", 0.0, 0.25)
		tween.tween_callback(flame.queue_free)

		# Smoke particle occasionally
		if randf() > 0.8:
			staff._spawn_smoke_particle(projectile.global_position)
	)
	timer.start()

func _spawn_smoke_particle(pos: Vector2):
	var smoke = ColorRect.new()
	smoke.size = Vector2(10, 10)
	smoke.color = Color(0.3, 0.3, 0.3, 0.4)
	smoke.pivot_offset = Vector2(5, 5)
	get_tree().current_scene.add_child(smoke)
	smoke.global_position = pos

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(smoke, "global_position:y", pos.y - 40, 0.5)
	tween.tween_property(smoke, "global_position:x", pos.x + randf_range(-15, 15), 0.5)
	tween.tween_property(smoke, "scale", Vector2(2.0, 2.0), 0.5)
	tween.tween_property(smoke, "modulate:a", 0.0, 0.5)
	tween.tween_callback(smoke.queue_free)

func _animate_lava_bubbles(center: Vector2, duration: float):
	var elapsed = 0.0
	var pool_radius = volcano_radius * 0.8

	while elapsed < duration:
		# Check if self is still valid after await
		if not is_instance_valid(self):
			return

		var delta = get_process_delta_time()
		elapsed += delta

		# Spawn bubbling lava particles randomly within pool
		if randf() < 0.3:  # ~30% chance per frame
			var bubble = ColorRect.new()
			bubble.size = Vector2(randf_range(8, 16), randf_range(8, 16))
			bubble.pivot_offset = bubble.size / 2
			bubble.color = LAVA_CORE if randf() > 0.4 else MAGMA_COLOR

			# Random position within pool
			var angle = randf() * TAU
			var dist = randf() * pool_radius * 0.9
			var spawn_pos = center + Vector2.from_angle(angle) * dist

			get_tree().current_scene.add_child(bubble)
			bubble.global_position = spawn_pos

			# Bubble rises and pops
			var tween = TweenHelper.new_tween()
			tween.set_parallel(true)
			tween.tween_property(bubble, "global_position:y", spawn_pos.y - randf_range(20, 40), 0.3)
			tween.tween_property(bubble, "scale", Vector2(1.5, 1.5), 0.15)
			tween.chain().tween_property(bubble, "scale", Vector2(0.2, 0.2), 0.15)
			tween.tween_property(bubble, "modulate:a", 0.0, 0.3)
			tween.tween_callback(bubble.queue_free)

		await get_tree().process_frame
