# SCRIPT: DarkConversionSkill.gd
# NecroStaff's Dark Conversion skill - raises killed enemies as allies
# LOCATION: res://Scenes/Weapons/NecroStaff/spells/DarkConversionSkill.gd

extends Node2D

# Dark Conversion settings
const SKILL_DURATION: float = 6.0  # 6 seconds of dark conversion
const MINION_DURATION: float = 15.0  # Minions last 15 seconds
const MAX_MINIONS: int = 6
const SPAWN_IMMUNITY_DURATION: float = 2.0

# Colors
const NECRO_DARK: Color = Color(0.1, 0.05, 0.15)
const NECRO_GLOW: Color = Color(0.4, 0.1, 0.5, 0.8)
const NECRO_SOUL: Color = Color(0.6, 0.2, 0.8, 0.9)

var player_ref: Node2D = null
var is_skill_active: bool = false
var skill_time_remaining: float = 0.0
var active_minions: Array = []

signal skill_completed
signal minion_spawned(minion: Node2D)

func initialize(player: Node2D):
	player_ref = player
	global_position = player.global_position

	# Make sure skill is visible above everything
	z_index = 100

	# Connect to enemy death events
	if CombatEventBus:
		CombatEventBus.enemy_died.connect(_on_enemy_died)

	_activate_dark_conversion()

func _exit_tree():
	# Clean up minions
	for minion in active_minions:
		if is_instance_valid(minion):
			minion.queue_free()
	active_minions.clear()

	if CombatEventBus and CombatEventBus.enemy_died.is_connected(_on_enemy_died):
		CombatEventBus.enemy_died.disconnect(_on_enemy_died)

func _process(delta: float):
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

func _activate_dark_conversion():
	is_skill_active = true
	skill_time_remaining = SKILL_DURATION

	# Big visual activation
	_create_skill_activation_effect()

	# Dark aura on player
	if player_ref:
		player_ref.modulate = Color(0.6, 0.4, 0.8, 1.0)

	if DamageNumberManager:
		DamageNumberManager.shake(0.3)

func _end_dark_conversion():
	is_skill_active = false
	skill_time_remaining = 0.0

	# Remove dark aura
	if player_ref and is_instance_valid(player_ref):
		player_ref.modulate = Color.WHITE

	skill_completed.emit()
	queue_free()

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

	# Get the scene file path from the dying enemy
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

	# Load and instantiate the SAME enemy scene
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
	minion_spawned.emit(minion)

	# Start lifetime countdown
	_start_minion_lifetime(minion)

func _convert_to_minion(minion: Node2D):
	# Remove from enemies group, add to minions
	if minion.is_in_group("enemies"):
		minion.remove_from_group("enemies")
	minion.add_to_group("player_minions")
	minion.add_to_group("converted_minion")

	# Apply dark visual effect
	minion.modulate = Color(0.4, 0.2, 0.6, 1.0)

	# Store reference to player
	minion.set_meta("is_converted", true)
	minion.set_meta("owner_player", player_ref)
	minion.set_meta("lifetime", MINION_DURATION)

	# Swap collision layers
	minion.collision_layer = 2
	minion.collision_mask = 5

	# Find and modify attack box
	var attack_box = minion.find_child("AttackBox", true, false)
	if attack_box and attack_box is Area2D:
		attack_box.collision_mask = 20

	# Find and modify hurt box
	var hurt_box = minion.find_child("HurtBox", true, false)
	if hurt_box and hurt_box is Area2D:
		hurt_box.collision_layer = 2
		hurt_box.collision_mask = 128
		hurt_box.monitoring = true
		hurt_box.monitorable = true

		# Spawn immunity
		hurt_box.set_deferred("monitorable", false)
		_apply_spawn_immunity(minion, hurt_box)

	# Clear player reference so it doesn't chase player
	if "player_reference" in minion:
		minion.player_reference = null

	if minion.has_method("set_target"):
		minion.set_target(null)

	# Add dark aura particle effect
	_add_dark_aura_to_minion(minion)

func _apply_spawn_immunity(minion: Node2D, hurt_box: Area2D):
	minion.set_meta("spawn_immune", true)
	minion.modulate = Color(0.7, 0.4, 1.0, 1.0)

	_create_immunity_shield(minion)

	var skill_ref = weakref(self)
	var minion_ref = weakref(minion)
	var hurt_box_ref = weakref(hurt_box)

	await get_tree().create_timer(SPAWN_IMMUNITY_DURATION).timeout

	var skill = skill_ref.get_ref()
	var m = minion_ref.get_ref()
	var hb = hurt_box_ref.get_ref()

	if not skill or not is_instance_valid(skill):
		return

	if m and is_instance_valid(m):
		m.set_meta("spawn_immune", false)
		m.modulate = Color(0.4, 0.2, 0.6, 1.0)

		if hb and is_instance_valid(hb):
			hb.monitorable = true

func _create_immunity_shield(minion: Node2D):
	var scene = get_tree().current_scene
	if not scene:
		return

	var minion_ref = weakref(minion)
	var skill_ref = weakref(self)

	var elapsed = 0.0
	while elapsed < SPAWN_IMMUNITY_DURATION:
		var m = minion_ref.get_ref()
		var skill = skill_ref.get_ref()

		if not skill or not is_instance_valid(skill):
			return
		if not m or not is_instance_valid(m):
			return

		var shield = ColorRect.new()
		shield.size = Vector2(50, 50)
		shield.color = Color(0.6, 0.3, 1.0, 0.4)
		shield.pivot_offset = Vector2(25, 25)
		shield.z_index = 100
		scene.add_child(shield)
		shield.global_position = m.global_position - Vector2(25, 25)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(shield, "scale", Vector2(1.5, 1.5), 0.3)
		tween.tween_property(shield, "modulate:a", 0.0, 0.3)
		tween.tween_callback(shield.queue_free)

		await get_tree().create_timer(0.2).timeout
		elapsed += 0.2

func _add_dark_aura_to_minion(minion: Node2D):
	var aura_timer = Timer.new()
	aura_timer.name = "DarkAuraTimer"
	aura_timer.wait_time = 0.15
	aura_timer.one_shot = false
	minion.add_child(aura_timer)

	var skill_ref = weakref(self)
	var minion_ref = weakref(minion)

	aura_timer.timeout.connect(func():
		var _skill = skill_ref.get_ref()
		var m = minion_ref.get_ref()
		if not m or not is_instance_valid(m):
			aura_timer.stop()
			return

		var scene = m.get_tree().current_scene if m.get_tree() else null
		if not scene:
			return

		var wisp = ColorRect.new()
		wisp.size = Vector2(8, 8)
		wisp.color = NECRO_SOUL
		wisp.pivot_offset = Vector2(4, 4)
		wisp.z_index = 100
		scene.add_child(wisp)
		wisp.global_position = m.global_position + Vector2(randf_range(-20, 20), randf_range(-10, 20))

		var tween = m.create_tween()
		if tween:
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

# Visual Effects
func _create_skill_activation_effect():
	if not player_ref:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Large outer dark wave
	var outer_wave = ColorRect.new()
	outer_wave.size = Vector2(200, 200)
	outer_wave.color = Color(0.2, 0.05, 0.3, 0.6)
	outer_wave.pivot_offset = Vector2(100, 100)
	outer_wave.z_index = 80
	scene.add_child(outer_wave)
	outer_wave.global_position = player_ref.global_position - Vector2(100, 100)
	outer_wave.scale = Vector2(0.2, 0.2)

	var outer_tween = create_tween()
	outer_tween.set_parallel(true)
	outer_tween.tween_property(outer_wave, "scale", Vector2(6, 6), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	outer_tween.tween_property(outer_wave, "modulate:a", 0.0, 0.6)
	outer_tween.tween_callback(outer_wave.queue_free)

	# Inner dark circle
	var circle = ColorRect.new()
	circle.size = Vector2(100, 100)
	circle.color = NECRO_DARK
	circle.pivot_offset = Vector2(50, 50)
	circle.z_index = 90
	scene.add_child(circle)
	circle.global_position = player_ref.global_position - Vector2(50, 50)
	circle.scale = Vector2(0.3, 0.3)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(circle, "scale", Vector2(8, 8), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(circle, "modulate:a", 0.0, 0.5)
	tween.tween_callback(circle.queue_free)

	# Purple energy core
	var core = ColorRect.new()
	core.size = Vector2(80, 80)
	core.color = Color(0.7, 0.3, 1.0, 0.9)
	core.pivot_offset = Vector2(40, 40)
	core.z_index = 100
	scene.add_child(core)
	core.global_position = player_ref.global_position - Vector2(40, 40)
	core.scale = Vector2(0.2, 0.2)

	var core_tween = create_tween()
	core_tween.set_parallel(true)
	core_tween.tween_property(core, "scale", Vector2(5, 5), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	core_tween.tween_property(core, "modulate:a", 0.0, 0.4)
	core_tween.tween_callback(core.queue_free)

	# Rising dark particles
	for i in range(16):
		var particle = ColorRect.new()
		particle.size = Vector2(10, 20)
		particle.color = NECRO_SOUL
		particle.pivot_offset = Vector2(5, 10)
		particle.z_index = 95
		scene.add_child(particle)

		var angle = (TAU / 16) * i
		particle.global_position = player_ref.global_position + Vector2.from_angle(angle) * 60

		var p_tween = create_tween()
		p_tween.set_parallel(true)
		p_tween.tween_property(particle, "global_position:y", particle.global_position.y - 100, 0.7)
		p_tween.tween_property(particle, "rotation", randf_range(-PI, PI), 0.7)
		p_tween.tween_property(particle, "modulate:a", 0.0, 0.7)
		p_tween.tween_callback(particle.queue_free)

func _create_dark_pulse():
	if not player_ref or not is_instance_valid(player_ref):
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Outer glow pulse
	var outer_pulse = ColorRect.new()
	outer_pulse.size = Vector2(60, 60)
	outer_pulse.color = Color(0.3, 0.1, 0.4, 0.4)
	outer_pulse.pivot_offset = Vector2(30, 30)
	outer_pulse.z_index = 70
	scene.add_child(outer_pulse)
	outer_pulse.global_position = player_ref.global_position - Vector2(30, 30)

	var outer_tween = create_tween()
	outer_tween.set_parallel(true)
	outer_tween.tween_property(outer_pulse, "scale", Vector2(5, 5), 0.35)
	outer_tween.tween_property(outer_pulse, "modulate:a", 0.0, 0.35)
	outer_tween.tween_callback(outer_pulse.queue_free)

	# Inner bright pulse
	var pulse = ColorRect.new()
	pulse.size = Vector2(40, 40)
	pulse.color = Color(0.6, 0.3, 0.8, 0.6)
	pulse.pivot_offset = Vector2(20, 20)
	pulse.z_index = 80
	scene.add_child(pulse)
	pulse.global_position = player_ref.global_position - Vector2(20, 20)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse, "scale", Vector2(4, 4), 0.3)
	tween.tween_property(pulse, "modulate:a", 0.0, 0.3)
	tween.tween_callback(pulse.queue_free)

func _create_dark_conversion_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Outer purple glow
	var glow = ColorRect.new()
	glow.size = Vector2(100, 100)
	glow.color = Color(0.5, 0.2, 0.7, 0.5)
	glow.pivot_offset = Vector2(50, 50)
	glow.z_index = 85
	scene.add_child(glow)
	glow.global_position = pos - Vector2(50, 50)
	glow.scale = Vector2(0.3, 0.3)

	var glow_tween = create_tween()
	glow_tween.set_parallel(true)
	glow_tween.tween_property(glow, "scale", Vector2(2, 2), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	glow_tween.tween_property(glow, "modulate:a", 0.0, 0.3)
	glow_tween.tween_callback(glow.queue_free)

	# Dark portal on ground
	var portal = ColorRect.new()
	portal.size = Vector2(80, 80)
	portal.color = NECRO_DARK
	portal.pivot_offset = Vector2(40, 40)
	portal.z_index = 90
	scene.add_child(portal)
	portal.global_position = pos - Vector2(40, 40)
	portal.scale = Vector2(0.2, 0.2)

	var tween = create_tween()
	tween.tween_property(portal, "scale", Vector2(1.5, 0.5), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.3)
	tween.tween_property(portal, "modulate:a", 0.0, 0.2)
	tween.tween_callback(portal.queue_free)

	# Bright core flash
	var core_flash = ColorRect.new()
	core_flash.size = Vector2(50, 50)
	core_flash.color = Color(0.8, 0.5, 1.0, 0.9)
	core_flash.pivot_offset = Vector2(25, 25)
	core_flash.z_index = 100
	scene.add_child(core_flash)
	core_flash.global_position = pos - Vector2(25, 25)
	core_flash.scale = Vector2(0.2, 0.2)

	var core_tween = create_tween()
	core_tween.set_parallel(true)
	core_tween.tween_property(core_flash, "scale", Vector2(1.8, 1.8), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	core_tween.tween_property(core_flash, "modulate:a", 0.0, 0.2)
	core_tween.tween_callback(core_flash.queue_free)

	# Dark wisps rising
	for i in range(10):
		var wisp = ColorRect.new()
		wisp.size = Vector2(8, 16)
		wisp.color = NECRO_SOUL if randf() > 0.4 else NECRO_GLOW
		wisp.pivot_offset = Vector2(4, 8)
		wisp.z_index = 95
		scene.add_child(wisp)
		wisp.global_position = pos + Vector2(randf_range(-30, 30), 10)

		var w_tween = create_tween()
		w_tween.set_parallel(true)
		w_tween.tween_property(wisp, "global_position:y", pos.y - 70, 0.5 + i * 0.05)
		w_tween.tween_property(wisp, "global_position:x", wisp.global_position.x + randf_range(-15, 15), 0.5 + i * 0.05)
		w_tween.tween_property(wisp, "rotation", randf_range(-0.5, 0.5), 0.5 + i * 0.05)
		w_tween.tween_property(wisp, "modulate:a", 0.0, 0.5 + i * 0.05)
		w_tween.tween_callback(wisp.queue_free)

	if DamageNumberManager:
		DamageNumberManager.shake(0.2)

func _create_minion_death_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	for i in range(6):
		var particle = ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.color = NECRO_GLOW
		particle.pivot_offset = Vector2(4, 4)
		particle.z_index = 100
		scene.add_child(particle)
		particle.global_position = pos

		var angle = (TAU / 6) * i
		var dir = Vector2.from_angle(angle)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", pos + dir * 40, 0.25)
		tween.tween_property(particle, "modulate:a", 0.0, 0.25)
		tween.tween_callback(particle.queue_free)
