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
const SKILL_DURATION: float = 6.0  # 6 seconds of dark conversion
const MINION_DURATION: float = 15.0  # Minions last 15 seconds
const MAX_MINIONS: int = 6

var is_skill_active: bool = false
var skill_time_remaining: float = 0.0
var active_minions: Array = []

# No preloading needed - we get scene path from the dying enemy directly

func _weapon_ready():
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

	# Connect to enemy death events
	if CombatEventBus:
		CombatEventBus.enemy_died.connect(_on_enemy_died)

func _exit_tree():
	super._exit_tree()

	# Clean up minions
	for minion in active_minions:
		if is_instance_valid(minion):
			minion.queue_free()
	active_minions.clear()

	if CombatEventBus and CombatEventBus.enemy_died.is_connected(_on_enemy_died):
		CombatEventBus.enemy_died.disconnect(_on_enemy_died)

func _weapon_process(delta: float):
	# Update skill duration
	if is_skill_active:
		skill_time_remaining -= delta
		if skill_time_remaining <= 0:
			_end_dark_conversion()
		else:
			# Pulsing dark aura around player during skill
			if Engine.get_process_frames() % 10 == 0:
				_create_dark_pulse()

	# Clean up dead minions
	active_minions = active_minions.filter(func(m): return is_instance_valid(m))

	# Update minion AI
	for minion in active_minions:
		if is_instance_valid(minion):
			_update_minion_ai(minion, delta)

# ============================================
# SKILL - DARK CONVERSION
# ============================================
func _is_async_skill() -> bool:
	return false  # Skill just activates a buff, no async needed

func _perform_skill() -> bool:
	if not player_reference:
		return false

	_activate_dark_conversion()
	return true

func _activate_dark_conversion():
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

	# Minion body uses layer 2 which is not in player weapon mask (20 = 4 + 16)

	# If enemy has player_reference, point it to enemies instead
	if "player_reference" in minion:
		minion.player_reference = null  # Clear so it doesn't chase player

	# Override the enemy's target finding if possible
	if minion.has_method("set_target"):
		minion.set_target(null)

	# Add dark aura particle effect
	_add_dark_aura_to_minion(minion)

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

# ============================================
# MINION AI OVERRIDE - Make converted enemies attack other enemies
# ============================================
func _update_minion_ai(minion: Node2D, _delta: float):
	if not is_instance_valid(minion):
		return

	# Find nearest REAL enemy (not other converted minions)
	var target = _find_nearest_real_enemy(minion.global_position)

	if target and is_instance_valid(target):
		# Override enemy's target to chase this enemy
		if "player_reference" in minion:
			# Temporarily set player_reference to the target so enemy AI chases it
			minion.player_reference = target
	else:
		# No enemies nearby, follow player
		if "player_reference" in minion and player_reference:
			var to_player = player_reference.global_position - minion.global_position
			if to_player.length() > 150:
				# Point toward player to make AI follow
				minion.player_reference = player_reference
			else:
				minion.player_reference = null  # Stay idle near player

func _find_nearest_real_enemy(from_pos: Vector2) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist = 400.0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		# Skip other converted minions
		if enemy.is_in_group("converted_minion"):
			continue
		var dist = from_pos.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	return nearest

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

func _create_minion_attack_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	for i in range(3):
		var slash = ColorRect.new()
		slash.size = Vector2(4, 18)
		slash.color = NECRO_SOUL
		slash.pivot_offset = Vector2(2, 9)
		scene.add_child(slash)
		slash.global_position = pos
		slash.rotation = (PI / 4) * (i - 1)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(slash, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(slash, "modulate:a", 0.0, 0.15)
		tween.tween_callback(slash.queue_free)

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

	var staff_ref = weakref(self)

	timer.timeout.connect(func():
		if not is_instance_valid(projectile):
			timer.stop()
			timer.queue_free()
			return

		var staff = staff_ref.get_ref()
		if not staff:
			timer.stop()
			timer.queue_free()
			return

		var scene = staff.get_tree().current_scene
		if not scene:
			return

		var trail = ColorRect.new()
		trail.size = Vector2(10, 10)
		trail.color = NECRO_GLOW
		trail.pivot_offset = Vector2(5, 5)
		scene.add_child(trail)
		trail.global_position = projectile.global_position

		var tween = TweenHelper.new_tween()
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
