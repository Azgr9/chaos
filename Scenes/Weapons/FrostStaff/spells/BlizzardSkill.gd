# SCRIPT: BlizzardSkill.gd
# FrostStaff's Blizzard skill - AoE slow zone with damage over time
# LOCATION: res://Scenes/Weapons/FrostStaff/spells/BlizzardSkill.gd

extends Node2D

# Blizzard settings
@export var blizzard_radius: float = 150.0
@export var blizzard_duration: float = 4.0
@export var damage_per_tick: float = 5.0
@export var tick_rate: float = 0.5

# Slow settings
var slow_duration: float = 2.0
var slow_amount: float = 0.5

# Colors
const ICE_GLOW: Color = Color(0.5, 0.8, 1.0, 0.3)
const ICE_CRYSTAL: Color = Color(0.9, 0.95, 1.0)

var player_ref: Node2D = null
var damage_multiplier: float = 1.0
var damage_type: int = 1  # DamageTypes.Type.ICE

signal skill_completed
signal dealt_damage(target: Node2D, damage: float)

func initialize(pos: Vector2, player: Node2D, magic_multiplier: float = 1.0):
	global_position = pos
	player_ref = player
	damage_multiplier = magic_multiplier

	# Make sure skill is visible above everything
	z_index = 100

	_create_blizzard()

func _create_blizzard():
	# Outer frost ring (largest, most transparent)
	var outer_ring = ColorRect.new()
	outer_ring.size = Vector2(blizzard_radius * 2.2, blizzard_radius * 2.2)
	outer_ring.color = Color(0.6, 0.85, 1.0, 0.2)
	outer_ring.pivot_offset = Vector2(blizzard_radius * 1.1, blizzard_radius * 1.1)
	outer_ring.position = -Vector2(blizzard_radius * 1.1, blizzard_radius * 1.1)
	outer_ring.z_index = -2
	add_child(outer_ring)

	# Mid frost ring
	var mid_ring = ColorRect.new()
	mid_ring.size = Vector2(blizzard_radius * 1.8, blizzard_radius * 1.8)
	mid_ring.color = Color(0.5, 0.8, 1.0, 0.35)
	mid_ring.pivot_offset = Vector2(blizzard_radius * 0.9, blizzard_radius * 0.9)
	mid_ring.position = -Vector2(blizzard_radius * 0.9, blizzard_radius * 0.9)
	mid_ring.z_index = -1
	add_child(mid_ring)

	# Visual base (ice ring - core)
	var base_visual = ColorRect.new()
	base_visual.size = Vector2(blizzard_radius * 2, blizzard_radius * 2)
	base_visual.color = Color(0.7, 0.9, 1.0, 0.5)
	base_visual.pivot_offset = Vector2(blizzard_radius, blizzard_radius)
	base_visual.position = -Vector2(blizzard_radius, blizzard_radius)
	base_visual.z_index = 0
	add_child(base_visual)

	# Create initial ice crystal burst
	_create_ice_burst()

	# Screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.3)

	# Spawn animation
	scale = Vector2(0.3, 0.3)
	var spawn_tween = create_tween()
	spawn_tween.tween_property(self, "scale", Vector2(1, 1), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Start blizzard effect
	_run_blizzard(base_visual)

func _create_ice_burst():
	var scene = get_tree().current_scene
	if not scene:
		return

	# Burst of ice crystals outward
	for i in range(12):
		var crystal = ColorRect.new()
		crystal.size = Vector2(12, 20)
		crystal.color = Color(0.9, 0.95, 1.0, 0.9)
		crystal.pivot_offset = Vector2(6, 10)
		crystal.z_index = 100
		scene.add_child(crystal)
		crystal.global_position = global_position

		var angle = (TAU / 12) * i
		var dir = Vector2.from_angle(angle)

		var tween = scene.create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(crystal, "global_position", global_position + dir * blizzard_radius * 0.8, 0.3)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(crystal, "rotation", angle, 0.3)
			tween.tween_property(crystal, "modulate:a", 0.0, 0.3)
			tween.tween_callback(crystal.queue_free)

func _run_blizzard(visual: ColorRect):
	var elapsed = 0.0
	var tick_timer = 0.0

	while elapsed < blizzard_duration:
		if not is_instance_valid(self):
			break

		var delta = get_process_delta_time()
		elapsed += delta
		tick_timer += delta

		# Spawn snowflake particles
		if randf() < 0.3:
			_spawn_snowflake()

		# Damage tick
		if tick_timer >= tick_rate:
			tick_timer = 0.0
			_blizzard_damage_tick()

		# Fade out near end
		if elapsed > blizzard_duration - 1.0 and is_instance_valid(visual):
			var fade = (blizzard_duration - elapsed) / 1.0
			visual.modulate.a = 0.3 * fade

		await get_tree().process_frame

	# Cleanup
	skill_completed.emit()
	queue_free()

func _blizzard_damage_tick():
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Skip converted minions
		if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
			continue

		var distance = enemy.global_position.distance_to(global_position)
		if distance < blizzard_radius:
			# Deal damage with ICE type to apply CHILL
			var tick_damage = damage_per_tick * damage_multiplier
			if enemy.has_method("take_damage"):
				enemy.take_damage(tick_damage, global_position, 50.0, 0.05, player_ref, damage_type)
				dealt_damage.emit(enemy, tick_damage)

			# Apply slow
			_apply_slow_effect(enemy)

func _apply_slow_effect(enemy: Node2D):
	if not is_instance_valid(enemy):
		return

	if enemy.has_method("apply_slow"):
		enemy.apply_slow(slow_amount, slow_duration)
	elif "speed" in enemy or "move_speed" in enemy:
		_temporary_slow(enemy)

func _temporary_slow(enemy: Node2D):
	var speed_property = "speed" if "speed" in enemy else "move_speed"
	var original_speed = enemy.get(speed_property)

	enemy.set(speed_property, original_speed * slow_amount)

	var original_modulate = enemy.modulate
	enemy.modulate = Color(0.6, 0.8, 1.0)

	var timer = get_tree().create_timer(slow_duration)
	timer.timeout.connect(func():
		if is_instance_valid(enemy):
			enemy.set(speed_property, original_speed)
			enemy.modulate = original_modulate
	)

func _spawn_snowflake():
	var snowflake = ColorRect.new()
	snowflake.size = Vector2(6, 6)
	snowflake.color = ICE_CRYSTAL
	snowflake.pivot_offset = Vector2(3, 3)
	snowflake.z_index = 100
	get_tree().current_scene.add_child(snowflake)

	# Random position within blizzard radius
	var angle = randf() * TAU
	var dist = randf() * blizzard_radius
	snowflake.global_position = global_position + Vector2.from_angle(angle) * dist + Vector2(0, -50)

	# Fall animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(snowflake, "global_position:y", snowflake.global_position.y + 80, 0.8)
	tween.tween_property(snowflake, "global_position:x", snowflake.global_position.x + randf_range(-20, 20), 0.8)
	tween.tween_property(snowflake, "rotation", randf_range(-PI, PI), 0.8)
	tween.tween_property(snowflake, "modulate:a", 0.0, 0.8)
	tween.tween_callback(snowflake.queue_free)
