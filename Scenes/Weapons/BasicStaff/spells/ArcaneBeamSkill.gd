# SCRIPT: ArcaneBeamSkill.gd
# BasicStaff's beam skill - fires a powerful arcane beam
# LOCATION: res://Scenes/Weapons/BasicStaff/spells/ArcaneBeamSkill.gd

extends Node2D

# Beam settings
@export var beam_damage: float = 50.0
@export var beam_range: float = 800.0
@export var beam_width: float = 32.0

# Colors
const ARCANE_BEAM: Color = Color(1.0, 1.0, 0.8, 1.0)  # Bright yellow-white
const ARCANE_GLOW: Color = Color(0.6, 0.9, 1.0, 0.6)  # Light blue glow

var player_ref: Node2D = null
var damage_multiplier: float = 1.0
var damage_type: int = 0  # DamageTypes.Type.PHYSICAL

signal skill_completed
signal dealt_damage(target: Node2D, damage: float)

func initialize(player: Node2D, direction: Vector2, magic_multiplier: float = 1.0, dmg_type: int = 0):
	player_ref = player
	damage_multiplier = magic_multiplier
	damage_type = dmg_type

	# Position at player
	global_position = player.global_position

	# Make sure skill is visible above everything
	z_index = 100

	# Fire beam in direction
	_fire_beam(direction)

func _fire_beam(direction: Vector2):
	var beam_visual = _create_beam_visual(direction)
	var final_damage = beam_damage * damage_multiplier

	_damage_enemies_in_beam(direction, final_damage)

	# Screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.4)

	await _animate_beam(beam_visual)

	skill_completed.emit()
	queue_free()

func _create_beam_visual(direction: Vector2) -> Node2D:
	var container = Node2D.new()
	container.position = Vector2.ZERO  # Local position at skill origin
	container.rotation = direction.angle()
	add_child(container)

	# Outer glow (biggest, behind everything)
	var outer_glow = ColorRect.new()
	outer_glow.color = Color(0.3, 0.7, 1.0, 0.4)
	outer_glow.size = Vector2(beam_range, beam_width * 1.5)
	outer_glow.position = Vector2(0, -beam_width * 0.75)
	outer_glow.z_index = -2
	container.add_child(outer_glow)

	# Mid glow
	var glow = ColorRect.new()
	glow.color = Color(0.5, 0.85, 1.0, 0.7)
	glow.size = Vector2(beam_range, beam_width)
	glow.position = Vector2(0, -beam_width * 0.5)
	glow.z_index = -1
	container.add_child(glow)

	# Core beam (brightest, on top)
	var core = ColorRect.new()
	core.color = ARCANE_BEAM
	core.size = Vector2(beam_range, beam_width * 0.5)
	core.position = Vector2(0, -beam_width * 0.25)
	core.z_index = 1
	container.add_child(core)

	# Edge highlights
	for y_pos in [-beam_width * 0.5, beam_width * 0.5 - 4]:
		var edge = ColorRect.new()
		edge.color = Color(1.0, 1.0, 1.0, 0.9)
		edge.size = Vector2(beam_range, 4)
		edge.position = Vector2(0, y_pos)
		edge.z_index = 2
		container.add_child(edge)

	# Origin flash (big bright circle at start)
	var flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.size = Vector2(80, 80)
	flash.position = Vector2(-40, -40)
	flash.pivot_offset = Vector2(40, 40)
	flash.z_index = 3
	container.add_child(flash)

	# Spawn particles along beam
	_spawn_beam_particles(direction)

	return container

func _spawn_beam_particles(direction: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	for i in range(20):
		var particle = ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.color = Color(0.8, 0.95, 1.0, 0.9)
		particle.pivot_offset = Vector2(4, 4)
		particle.z_index = 100
		scene.add_child(particle)

		var dist = randf_range(50, beam_range - 50)
		particle.global_position = global_position + direction * dist + Vector2(randf_range(-10, 10), randf_range(-10, 10))

		var tween = scene.create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(particle, "scale", Vector2(0.2, 0.2), 0.3)
			tween.tween_property(particle, "modulate:a", 0.0, 0.3)
			tween.tween_callback(particle.queue_free)

func _animate_beam(beam_visual: Node2D):
	beam_visual.modulate = Color(1, 1, 1, 0)
	beam_visual.scale = Vector2(1, 0.3)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(beam_visual, "modulate:a", 1.0, 0.05)
	tween.tween_property(beam_visual, "scale:y", 1.2, 0.05)

	await tween.finished

	if not is_instance_valid(self) or not is_instance_valid(beam_visual):
		return

	await get_tree().create_timer(0.15).timeout

	if not is_instance_valid(self) or not is_instance_valid(beam_visual):
		return

	var fade = create_tween()
	fade.set_parallel(true)
	fade.tween_property(beam_visual, "modulate:a", 0.0, 0.3)
	fade.tween_property(beam_visual, "scale:y", 0.1, 0.3)

	await fade.finished

func _damage_enemies_in_beam(direction: Vector2, final_damage: float):
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_enemies: Array = []
	var hitbox_tolerance: float = 16.0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Skip converted minions
		if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
			continue

		var to_enemy = enemy.global_position - global_position
		var distance_along = to_enemy.dot(direction)

		if distance_along < 0 or distance_along > beam_range:
			continue

		var perpendicular = to_enemy - direction * distance_along
		if perpendicular.length() <= beam_width * 0.5 + hitbox_tolerance:
			hit_enemies.append(enemy)

	for enemy in hit_enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(final_damage, global_position, 200.0, 0.1, player_ref, damage_type)
			dealt_damage.emit(enemy, final_damage)
			_create_beam_hit_effect(enemy.global_position)

func _create_beam_hit_effect(pos: Vector2):
	var flash = ColorRect.new()
	flash.color = ARCANE_BEAM
	flash.size = Vector2(32, 32)
	flash.global_position = pos - Vector2(16, 16)
	flash.pivot_offset = Vector2(16, 16)
	get_tree().current_scene.add_child(flash)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2, 2), 0.2)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)
