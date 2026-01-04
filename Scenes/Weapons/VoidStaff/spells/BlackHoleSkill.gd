# SCRIPT: BlackHoleSkill.gd
# VoidStaff's Black Hole skill - pulls enemies and deals AoE damage
# LOCATION: res://Scenes/Weapons/VoidStaff/spells/BlackHoleSkill.gd

extends Node2D

# Black Hole settings
@export var black_hole_radius: float = 180.0
@export var black_hole_duration: float = 3.0
@export var damage_per_tick: float = 12.0
@export var tick_rate: float = 0.3
@export var pull_strength: float = 150.0

# Colors
const VOID_CORE: Color = Color(0.1, 0.0, 0.15)
const VOID_GLOW: Color = Color(0.5, 0.2, 0.7, 0.8)

var player_ref: Node2D = null
var damage_multiplier: float = 1.0

signal skill_completed
signal dealt_damage(target: Node2D, damage: float)

func initialize(pos: Vector2, player: Node2D, magic_multiplier: float = 1.0):
	global_position = pos
	player_ref = player
	damage_multiplier = magic_multiplier

	# Make sure skill is visible above everything
	z_index = 100

	_create_black_hole()

func _create_black_hole():
	# Outer distortion ring (largest)
	var outer_ring = ColorRect.new()
	outer_ring.size = Vector2(160, 160)
	outer_ring.color = Color(0.3, 0.1, 0.4, 0.3)
	outer_ring.pivot_offset = Vector2(80, 80)
	outer_ring.position = Vector2(-80, -80)
	outer_ring.z_index = -3
	add_child(outer_ring)

	# Mid ring
	var mid_ring = ColorRect.new()
	mid_ring.size = Vector2(120, 120)
	mid_ring.color = Color(0.4, 0.15, 0.5, 0.5)
	mid_ring.pivot_offset = Vector2(60, 60)
	mid_ring.position = Vector2(-60, -60)
	mid_ring.z_index = -2
	add_child(mid_ring)

	# Visual - purple ring
	var ring = ColorRect.new()
	ring.size = Vector2(80, 80)
	ring.color = Color(0.5, 0.2, 0.6, 0.7)
	ring.pivot_offset = Vector2(40, 40)
	ring.position = Vector2(-40, -40)
	ring.z_index = -1
	add_child(ring)

	# Visual - dark core
	var core = ColorRect.new()
	core.size = Vector2(50, 50)
	core.color = Color(0.05, 0.0, 0.08, 1.0)  # Almost pure black
	core.pivot_offset = Vector2(25, 25)
	core.position = Vector2(-25, -25)
	core.z_index = 0
	add_child(core)

	# Bright event horizon edge
	var horizon = ColorRect.new()
	horizon.size = Vector2(60, 60)
	horizon.color = Color(0.7, 0.4, 1.0, 0.8)
	horizon.pivot_offset = Vector2(30, 30)
	horizon.position = Vector2(-30, -30)
	horizon.z_index = 1
	add_child(horizon)

	# Spawn animation
	scale = Vector2(0.1, 0.1)
	var spawn_tween = create_tween()
	spawn_tween.tween_property(self, "scale", Vector2(1, 1), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Screen effect
	if DamageNumberManager:
		DamageNumberManager.shake(0.5)

	# Start black hole effect
	_run_black_hole(core, ring, outer_ring, mid_ring, horizon)

func _run_black_hole(core: ColorRect, ring: ColorRect, outer_ring: ColorRect, mid_ring: ColorRect, horizon: ColorRect):
	var elapsed = 0.0
	var tick_timer = 0.0
	var rotation_speed = 3.0

	while elapsed < black_hole_duration:
		if not is_instance_valid(self):
			break

		var delta = get_process_delta_time()
		elapsed += delta
		tick_timer += delta

		# Rotate all visual layers at different speeds
		if is_instance_valid(outer_ring):
			outer_ring.rotation += delta * rotation_speed * 0.3
		if is_instance_valid(mid_ring):
			mid_ring.rotation -= delta * rotation_speed * 0.5
		if is_instance_valid(ring):
			ring.rotation += delta * rotation_speed
		if is_instance_valid(core):
			core.rotation -= delta * rotation_speed * 0.5
		if is_instance_valid(horizon):
			horizon.rotation += delta * rotation_speed * 1.5

		# Pulsing effect on all layers
		var pulse = 1.0 + sin(elapsed * 5) * 0.1
		var pulse2 = 1.0 + sin(elapsed * 3) * 0.15
		if is_instance_valid(ring):
			ring.scale = Vector2(pulse, pulse)
		if is_instance_valid(horizon):
			horizon.scale = Vector2(pulse2, pulse2)
		if is_instance_valid(outer_ring):
			outer_ring.scale = Vector2(1.0 + sin(elapsed * 2) * 0.08, 1.0 + sin(elapsed * 2) * 0.08)

		# Pull enemies toward center
		_pull_enemies_to_center(delta)

		# Spawn void particles being sucked in
		if randf() < 0.4:
			_spawn_void_particle()

		# Damage tick
		if tick_timer >= tick_rate:
			tick_timer = 0.0
			_black_hole_damage_tick()

		# Fade out near end
		if elapsed > black_hole_duration - 0.5:
			var fade = (black_hole_duration - elapsed) / 0.5
			modulate.a = fade

		await get_tree().process_frame

	# Collapse animation
	if is_instance_valid(self):
		var collapse_tween = create_tween()
		collapse_tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.2)
		collapse_tween.tween_callback(func():
			_create_void_burst()
			skill_completed.emit()
			queue_free()
		)

func _pull_enemies_to_center(delta: float):
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Skip converted minions
		if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
			continue

		var to_center = global_position - enemy.global_position
		var distance = to_center.length()

		if distance < black_hole_radius and distance > 20:
			# Pull strength increases as enemies get closer
			var pull_factor = 1.0 - (distance / black_hole_radius)
			var pull_force = to_center.normalized() * pull_strength * pull_factor * delta

			# Move enemy toward center
			enemy.global_position += pull_force

func _black_hole_damage_tick():
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Skip converted minions
		if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
			continue

		var distance = enemy.global_position.distance_to(global_position)
		if distance < black_hole_radius:
			# More damage at center
			var damage_factor = 1.0 + (1.0 - distance / black_hole_radius) * 0.5
			var tick_damage = damage_per_tick * damage_multiplier * damage_factor

			if enemy.has_method("take_damage"):
				enemy.take_damage(tick_damage, global_position, 0.0, 0.1, player_ref)
				dealt_damage.emit(enemy, tick_damage)

			# Void hit effect
			_create_void_hit_effect(enemy.global_position)

func _spawn_void_particle():
	var particle = ColorRect.new()
	particle.size = Vector2(10, 10)
	particle.color = VOID_GLOW
	particle.pivot_offset = Vector2(5, 5)
	particle.z_index = 100
	get_tree().current_scene.add_child(particle)

	# Start at edge of radius
	var angle = randf() * TAU
	var start_pos = global_position + Vector2.from_angle(angle) * black_hole_radius
	particle.global_position = start_pos

	# Spiral toward center
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(particle, "global_position", global_position, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(particle, "scale", Vector2(0.2, 0.2), 0.5)
	tween.tween_property(particle, "rotation", randf_range(PI, TAU), 0.5)
	tween.tween_callback(particle.queue_free)

func _create_void_hit_effect(pos: Vector2):
	var flash = ColorRect.new()
	flash.size = Vector2(16, 16)
	flash.color = VOID_GLOW
	flash.pivot_offset = Vector2(8, 8)
	flash.z_index = 100
	get_tree().current_scene.add_child(flash)
	flash.global_position = pos - Vector2(8, 8)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(0.3, 0.3), 0.15)
	tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)

func _create_void_burst():
	# Final explosion when black hole collapses
	if DamageNumberManager:
		DamageNumberManager.shake(0.4)

	for i in range(12):
		var particle = ColorRect.new()
		particle.size = Vector2(20, 20)
		particle.color = Color(0.4, 0.1, 0.5, 0.9)
		particle.pivot_offset = Vector2(10, 10)
		particle.z_index = 100
		get_tree().current_scene.add_child(particle)
		particle.global_position = global_position

		var angle = (TAU / 12) * i
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(100, 180)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", global_position + dir * dist, 0.3)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_property(particle, "scale", Vector2(0.5, 0.5), 0.3)
		tween.tween_callback(particle.queue_free)
