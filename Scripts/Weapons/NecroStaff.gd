# SCRIPT: NecroStaff.gd
# Necromancer Staff - Dark Conversion skill raises killed enemies as allies

class_name NecroStaff
extends MagicWeapon

# ============================================
# NECRO COLORS
# ============================================
const NECRO_DARK: Color = Color(0.1, 0.05, 0.15)  # Very dark purple-black
const NECRO_GLOW: Color = Color(0.4, 0.1, 0.5, 0.8)  # Dark purple glow
const NECRO_SOUL: Color = Color(0.6, 0.2, 0.8, 0.9)  # Purple soul
const NECRO_AURA: Color = Color(0.2, 0.0, 0.3, 0.5)  # Dark aura

# ============================================
# DARK CONVERSION SYSTEM
# ============================================
const PROJECTILE_SCENE_PATH = preload("res://Scenes/Weapons/NecroStaff/spells/NecroProjectile.tscn")
const SKILL_SCENE = preload("res://Scenes/Weapons/NecroStaff/spells/DarkConversionSkill.tscn")

const SKILL_DURATION: float = 6.0  # 6 seconds of dark conversion
const MINION_DURATION: float = 15.0  # Minions last 15 seconds
const MAX_MINIONS: int = 6

var is_skill_active: bool = false
var skill_time_remaining: float = 0.0
var active_minions: Array = []
var _active_skill_instance: Node2D = null

func _weapon_ready():
	# Set projectile scene
	projectile_scene = PROJECTILE_SCENE_PATH

	attack_cooldown = 0.35
	projectile_spread = 0.1
	multi_shot = 1
	damage = 12.0

	staff_color = NECRO_DARK
	muzzle_flash_color = NECRO_GLOW

	max_attacks_per_second = 3.0
	min_cooldown = 0.2

	skill_cooldown = 20.0
	beam_damage = 0.0

func _exit_tree():
	super._exit_tree()

	# Clean up minions
	for minion in active_minions:
		if is_instance_valid(minion):
			minion.queue_free()
	active_minions.clear()

	# Clean up skill instance
	if is_instance_valid(_active_skill_instance):
		_active_skill_instance.queue_free()

# ============================================
# SKILL - DARK CONVERSION
# ============================================
func _is_async_skill() -> bool:
	return false  # Skill just activates a buff, no async needed

func _perform_skill() -> bool:
	if not player_reference:
		return false

	# Spawn DarkConversionSkill scene
	var skill = SKILL_SCENE.instantiate()
	get_tree().current_scene.add_child(skill)
	skill.initialize(player_reference)
	_active_skill_instance = skill

	# Connect to track skill state
	skill.skill_completed.connect(_on_skill_completed)

	is_skill_active = true
	return true

func _on_skill_completed():
	is_skill_active = false
	_active_skill_instance = null

func _unused_activate_dark_conversion():
	# NOTE: This is now handled by DarkConversionSkill scene
	is_skill_active = true
	skill_time_remaining = SKILL_DURATION

	# Big visual activation
	_create_skill_activation_effect()

	# Dark aura on player
	if player_reference:
		player_reference.modulate = Color(0.6, 0.4, 0.8, 1.0)

	if DamageNumberManager:
		DamageNumberManager.shake(0.3)

func _end_dark_conversion():
	is_skill_active = false
	skill_time_remaining = 0.0

	# Remove dark aura
	if player_reference and is_instance_valid(player_reference):
		player_reference.modulate = Color.WHITE

	_end_skill_invulnerability()

# ============================================
# ENEMY DEATH HANDLER - Spawn as minion
# ============================================
func _on_enemy_died(enemy: Node2D, killer: Node2D):
	if not is_instance_valid(self):
		return

	# Only convert if skill is active and killer is player
	if not is_skill_active:
		return

	if not killer or not killer.is_in_group("player"):
		return

	# Check minion limit
	if active_minions.size() >= MAX_MINIONS:
		return

	# Get the scene file path from the dying enemy - works for ANY enemy type!
	var enemy_scene_path = enemy.scene_file_path
	if enemy_scene_path.is_empty():
		return

	# Store enemy info before it's gone
	var enemy_pos = enemy.global_position
	var enemy_scale = enemy.scale if enemy else Vector2.ONE

	# Spawn dark version using the SAME scene file
	_spawn_dark_minion(enemy_pos, enemy_scene_path, enemy_scale)

func _spawn_dark_minion(pos: Vector2, scene_path: String, original_scale: Vector2):
	var current_scene = get_tree().current_scene
	if not current_scene:
		return

	# Dark conversion animation
	_create_dark_conversion_effect(pos)

	# Delay spawn for effect
	await get_tree().create_timer(0.4).timeout

	if not is_instance_valid(self):
		return

	# Load and instantiate the SAME enemy scene - works for ANY enemy!
	var enemy_scene = load(scene_path)
	if not enemy_scene:
		return

	var minion = enemy_scene.instantiate()
	if not minion:
		return

	# Add to scene
	current_scene.add_child(minion)
	minion.global_position = pos
	minion.scale = original_scale

	# Convert enemy to be on our side
	_convert_to_minion(minion)

	active_minions.append(minion)

	# Start lifetime countdown
	_start_minion_lifetime(minion)

func _convert_to_minion(minion: Node2D):
	# Remove from enemies group, add to minions
	if minion.is_in_group("enemies"):
		minion.remove_from_group("enemies")
	minion.add_to_group("player_minions")
	minion.add_to_group("converted_minion")

	# Apply dark visual effect
	minion.modulate = Color(0.4, 0.2, 0.6, 1.0)  # Dark purple tint

	# Store reference to player and staff for AI override
	minion.set_meta("is_converted", true)
	minion.set_meta("owner_player", player_reference)
	minion.set_meta("lifetime", MINION_DURATION)

	# Swap collision layers - now friendly to player, hostile to enemies
	# Original: collision_layer = 4 (enemy), collision_mask = 9 (player + world)
	# New: collision_layer = 2 (player ally), collision_mask = 5 (enemy + world)
	minion.collision_layer = 2
	minion.collision_mask = 5

	# Find and modify attack box to hit enemies instead of player
	var attack_box = minion.find_child("AttackBox", true, false)
	if attack_box and attack_box is Area2D:
		# Original: collision_layer = 128, collision_mask = 2 (player)
		# New: collision_mask = 4 (enemies) + 16 (enemy hurtbox)
		attack_box.collision_mask = 20  # 4 + 16

	# Find and modify hurt box - INVISIBLE TO PLAYER WEAPONS, BUT VISIBLE TO ENEMY ATTACKS
	var hurt_box = minion.find_child("HurtBox", true, false)
	if hurt_box and hurt_box is Area2D:
		# Original: collision_layer = 16, collision_mask = 96 (player weapons)
		# New: collision_layer = 2 (player/ally layer), collision_mask = 128 (enemy attack boxes)
		# This makes minions targetable by enemy attacks but not player weapons
		hurt_box.collision_layer = 2  # Player ally layer - not detected by player weapons (mask 20)
		hurt_box.collision_mask = 128  # Detect enemy attack boxes
		hurt_box.monitoring = true
		hurt_box.monitorable = true

		# SPAWN IMMUNITY: Disable hurt box for 2 seconds after spawn
		hurt_box.set_deferred("monitorable", false)
		_apply_spawn_immunity(minion, hurt_box)

	# Minion body uses layer 2 which is not in player weapon mask (20 = 4 + 16)

	# If enemy has player_reference, point it to enemies instead
	if "player_reference" in minion:
		minion.player_reference = null  # Clear so it doesn't chase player

	# Override the enemy's target finding if possible
	if minion.has_method("set_target"):
		minion.set_target(null)

	# Add dark aura particle effect
	_add_dark_aura_to_minion(minion)

const SPAWN_IMMUNITY_DURATION: float = 2.0  # 2 seconds of immunity after spawn

func _apply_spawn_immunity(minion: Node2D, hurt_box: Area2D):
	# Mark as immune
	minion.set_meta("spawn_immune", true)

	# Visual effect - bright glow during immunity
	minion.modulate = Color(0.7, 0.4, 1.0, 1.0)  # Bright purple glow

	# Add immunity shield visual
	_create_immunity_shield(minion)

	# Wait for immunity duration
	var staff_ref = weakref(self)
	var minion_ref = weakref(minion)
	var hurt_box_ref = weakref(hurt_box)

	await get_tree().create_timer(SPAWN_IMMUNITY_DURATION).timeout

	var staff = staff_ref.get_ref()
	var m = minion_ref.get_ref()
	var hb = hurt_box_ref.get_ref()

	if not staff or not is_instance_valid(staff):
		return

	# Remove immunity
	if m and is_instance_valid(m):
		m.set_meta("spawn_immune", false)
		m.modulate = Color(0.4, 0.2, 0.6, 1.0)  # Back to normal dark purple

		# Re-enable hurt box
		if hb and is_instance_valid(hb):
			hb.monitorable = true

func _create_immunity_shield(minion: Node2D):
	var scene = get_tree().current_scene
	if not scene:
		return

	var minion_ref = weakref(minion)
	var staff_ref = weakref(self)

	# Create pulsing shield effect during immunity
	var elapsed = 0.0
	while elapsed < SPAWN_IMMUNITY_DURATION:
		var m = minion_ref.get_ref()
		var staff = staff_ref.get_ref()

		if not staff or not is_instance_valid(staff):
			return
		if not m or not is_instance_valid(m):
			return

		# Create shield pulse particle
		var shield = ColorRect.new()
		shield.size = Vector2(50, 50)
		shield.color = Color(0.6, 0.3, 1.0, 0.4)
		shield.pivot_offset = Vector2(25, 25)
		scene.add_child(shield)
		shield.global_position = m.global_position - Vector2(25, 25)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(shield, "scale", Vector2(1.5, 1.5), 0.3)
		tween.tween_property(shield, "modulate:a", 0.0, 0.3)
		tween.tween_callback(shield.queue_free)

		await get_tree().create_timer(0.2).timeout
		elapsed += 0.2

func _add_dark_aura_to_minion(minion: Node2D):
	# Create a timer for continuous dark particles
	var aura_timer = Timer.new()
	aura_timer.name = "DarkAuraTimer"
	aura_timer.wait_time = 0.15
	aura_timer.one_shot = false
	minion.add_child(aura_timer)

	var staff_ref = weakref(self)
	var minion_ref = weakref(minion)

	aura_timer.timeout.connect(func():
		var staff = staff_ref.get_ref()
		var m = minion_ref.get_ref()
		if not staff or not m or not is_instance_valid(m):
			aura_timer.stop()
			return

		var scene = staff.get_tree().current_scene
		if not scene:
			return

		# Dark wisp particle
		var wisp = ColorRect.new()
		wisp.size = Vector2(8, 8)
		wisp.color = NECRO_SOUL
		wisp.pivot_offset = Vector2(4, 4)
		scene.add_child(wisp)
		wisp.global_position = m.global_position + Vector2(randf_range(-20, 20), randf_range(-10, 20))

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(wisp, "global_position:y", wisp.global_position.y - 30, 0.4)
		tween.tween_property(wisp, "modulate:a", 0.0, 0.4)
		tween.tween_callback(wisp.queue_free)
	)
	aura_timer.start()

func _start_minion_lifetime(minion: Node2D):
	var lifetime = MINION_DURATION

	while lifetime > 0 and is_instance_valid(minion):
		await get_tree().create_timer(0.1).timeout

		if not is_instance_valid(minion):
			break

		lifetime -= 0.1
		minion.set_meta("lifetime", lifetime)

		# Fade out near end
		if lifetime < 3.0:
			var fade = lifetime / 3.0
			minion.modulate.a = fade

	if is_instance_valid(minion):
		_create_minion_death_effect(minion.global_position)
		active_minions.erase(minion)
		minion.queue_free()

# ============================================
# VISUAL EFFECTS
# ============================================
func _create_skill_activation_effect():
	if not player_reference:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Expanding dark circle
	var circle = ColorRect.new()
	circle.size = Vector2(100, 100)
	circle.color = NECRO_DARK
	circle.pivot_offset = Vector2(50, 50)
	scene.add_child(circle)
	circle.global_position = player_reference.global_position - Vector2(50, 50)
	circle.scale = Vector2(0.3, 0.3)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(circle, "scale", Vector2(8, 8), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(circle, "modulate:a", 0.0, 0.5)
	tween.tween_callback(circle.queue_free)

	# Rising dark particles
	for i in range(12):
		var particle = ColorRect.new()
		particle.size = Vector2(8, 16)
		particle.color = NECRO_SOUL
		particle.pivot_offset = Vector2(4, 8)
		scene.add_child(particle)

		var angle = (TAU / 12) * i
		particle.global_position = player_reference.global_position + Vector2.from_angle(angle) * 60

		var p_tween = TweenHelper.new_tween()
		p_tween.set_parallel(true)
		p_tween.tween_property(particle, "global_position:y", particle.global_position.y - 80, 0.6)
		p_tween.tween_property(particle, "rotation", randf_range(-PI, PI), 0.6)
		p_tween.tween_property(particle, "modulate:a", 0.0, 0.6)
		p_tween.tween_callback(particle.queue_free)

func _create_dark_pulse():
	if not player_reference or not is_instance_valid(player_reference):
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	var pulse = ColorRect.new()
	pulse.size = Vector2(40, 40)
	pulse.color = Color(NECRO_GLOW.r, NECRO_GLOW.g, NECRO_GLOW.b, 0.3)
	pulse.pivot_offset = Vector2(20, 20)
	scene.add_child(pulse)
	pulse.global_position = player_reference.global_position - Vector2(20, 20)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse, "scale", Vector2(4, 4), 0.3)
	tween.tween_property(pulse, "modulate:a", 0.0, 0.3)
	tween.tween_callback(pulse.queue_free)

func _create_dark_conversion_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Dark portal on ground
	var portal = ColorRect.new()
	portal.size = Vector2(60, 60)
	portal.color = NECRO_DARK
	portal.pivot_offset = Vector2(30, 30)
	scene.add_child(portal)
	portal.global_position = pos - Vector2(30, 30)
	portal.scale = Vector2(0.2, 0.2)

	var tween = TweenHelper.new_tween()
	tween.tween_property(portal, "scale", Vector2(1.5, 0.4), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.3)
	tween.tween_property(portal, "modulate:a", 0.0, 0.2)
	tween.tween_callback(portal.queue_free)

	# Dark wisps rising
	for i in range(6):
		var wisp = ColorRect.new()
		wisp.size = Vector2(6, 12)
		wisp.color = NECRO_SOUL
		wisp.pivot_offset = Vector2(3, 6)
		scene.add_child(wisp)
		wisp.global_position = pos + Vector2(randf_range(-25, 25), 10)

		var w_tween = TweenHelper.new_tween()
		w_tween.set_parallel(true)
		w_tween.tween_property(wisp, "global_position:y", pos.y - 50, 0.4 + i * 0.05)
		w_tween.tween_property(wisp, "modulate:a", 0.0, 0.4 + i * 0.05)
		w_tween.tween_callback(wisp.queue_free)

	if DamageNumberManager:
		DamageNumberManager.shake(0.15)

func _create_minion_death_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	for i in range(6):
		var particle = ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.color = NECRO_GLOW
		particle.pivot_offset = Vector2(4, 4)
		scene.add_child(particle)
		particle.global_position = pos

		var angle = (TAU / 6) * i
		var dir = Vector2.from_angle(angle)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", pos + dir * 40, 0.25)
		tween.tween_property(particle, "modulate:a", 0.0, 0.25)
		tween.tween_callback(particle.queue_free)

# ============================================
# PROJECTILE CUSTOMIZATION
# ============================================
func _customize_projectile(projectile: Node2D):
	if projectile.has_node("Sprite"):
		var sprite_node = projectile.get_node("Sprite")
		sprite_node.color = NECRO_DARK
		sprite_node.size = Vector2(12, 12)

	_add_dark_trail(projectile)

func _add_dark_trail(projectile: Node2D):
	var timer = Timer.new()
	timer.wait_time = 0.04
	timer.one_shot = false
	projectile.add_child(timer)

	# Use weakref to safely capture references
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

		var trail = ColorRect.new()
		trail.size = Vector2(10, 10)
		trail.color = NECRO_GLOW
		trail.pivot_offset = Vector2(5, 5)
		trail.z_index = 100
		tree.current_scene.add_child(trail)
		trail.global_position = p.global_position

		var tween = tree.create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(trail, "scale", Vector2(0.2, 0.2), 0.15)
			tween.tween_property(trail, "modulate:a", 0.0, 0.15)
			tween.tween_callback(trail.queue_free)
	)
	timer.start()

func _play_attack_animation():
	if muzzle_flash:
		muzzle_flash.modulate.a = 1.0
		muzzle_flash.color = NECRO_GLOW
		var flash_tween = TweenHelper.new_tween()
		flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.1)

	var recoil_tween = TweenHelper.new_tween()
	recoil_tween.tween_property(self, "position:x", -8, 0.05)
	recoil_tween.tween_property(self, "position:x", 0, 0.1)

	if sprite:
		sprite.color = NECRO_GLOW
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and sprite:
			sprite.color = staff_color

func _get_projectile_color() -> Color:
	return NECRO_DARK

func _get_beam_color() -> Color:
	return NECRO_GLOW

func _get_beam_glow_color() -> Color:
	return NECRO_SOUL

# Trail colors - Dark necromantic soul energy
func _get_trail_color() -> Color:
	return Color(0.3, 0.1, 0.4, 0.9)  # Dark purple-black

func _get_trail_glow_color() -> Color:
	return Color(0.6, 0.2, 0.8, 1.0)  # Soul purple

func _get_trail_glow_intensity() -> float:
	return 1.6

func _get_trail_pulse_speed() -> float:
	return 2.5  # Slow, ghostly

func _get_trail_sparkle_amount() -> float:
	return 0.25  # Some soul wisps
