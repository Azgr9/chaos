# SCRIPT: ChainLightningSkill.gd
# LightningStaff's Chain Lightning skill - chains between enemies
# LOCATION: res://Scenes/Weapons/LightningStaff/spells/ChainLightningSkill.gd

extends Node2D

# Chain lightning settings
@export var chain_lightning_duration: float = 3.0
@export var chain_range: float = 600.0
@export var chain_damage: float = 15.0
@export var max_chains: int = 5
@export var zap_interval: float = 0.3
@export var stun_duration: float = 0.3

# Colors
const ELECTRIC_CORE: Color = Color(0.6, 1.0, 1.0)  # Bright cyan
const ELECTRIC_GLOW: Color = Color(0.0, 0.8, 1.0, 0.9)  # Strong cyan
const ELECTRIC_SPARK: Color = Color(1.0, 1.0, 0.8)  # White-yellow

var player_ref: Node2D = null
var damage_multiplier: float = 1.0
var damage_type: int = 3  # DamageTypes.Type.ELECTRIC

# Timers
var ability_duration_timer: Timer
var zap_timer: Timer
var ability_active: bool = false

signal skill_completed
signal dealt_damage(target: Node2D, damage: float)

func initialize(player: Node2D, magic_multiplier: float = 1.0):
	player_ref = player
	damage_multiplier = magic_multiplier
	global_position = player.global_position
	z_index = 100

	_setup_timers()
	_activate_chain_lightning()

func _setup_timers():
	ability_duration_timer = Timer.new()
	ability_duration_timer.one_shot = true
	ability_duration_timer.timeout.connect(_on_ability_duration_finished)
	add_child(ability_duration_timer)

	zap_timer = Timer.new()
	zap_timer.one_shot = false
	zap_timer.timeout.connect(_perform_chain_lightning)
	add_child(zap_timer)

func _activate_chain_lightning():
	ability_active = true
	ability_duration_timer.start(chain_lightning_duration)
	zap_timer.start(zap_interval)
	# Immediately perform first chain
	_perform_chain_lightning()

func _on_ability_duration_finished():
	ability_active = false
	zap_timer.stop()
	skill_completed.emit()
	queue_free()

func _perform_chain_lightning():
	if not ability_active or not player_ref or not is_instance_valid(player_ref):
		return

	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var closest_enemy = _find_closest_enemy(player_ref.global_position, enemies, [])
	if not closest_enemy:
		return

	# Build chain of targets - enemy to enemy
	var chain_targets = [closest_enemy]
	var current_target = closest_enemy

	for i in range(max_chains - 1):
		var next_target = _find_closest_enemy(current_target.global_position, enemies, chain_targets)
		if next_target:
			chain_targets.append(next_target)
			current_target = next_target
		else:
			break

	# Damage and stun all targets in chain
	for target in chain_targets:
		if is_instance_valid(target) and target.has_method("take_damage"):
			var final_damage = chain_damage * damage_multiplier
			target.take_damage(final_damage, player_ref.global_position, 200.0, stun_duration, player_ref, damage_type)
			dealt_damage.emit(target, final_damage)
			_apply_stun_effect(target)

	# Draw lightning chain - player to first, then enemy to enemy
	_draw_lightning_chain(chain_targets)

func _find_closest_enemy(from_position: Vector2, enemies: Array, exclude: Array) -> Node2D:
	var closest: Node2D = null
	var closest_dist = chain_range

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy in exclude:
			continue
		if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
			continue

		var dist = from_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy

	return closest

func _draw_lightning_chain(targets: Array):
	if targets.is_empty() or not player_ref or not is_instance_valid(player_ref):
		return

	# Lightning from player to first target
	if is_instance_valid(targets[0]):
		_create_lightning_bolt(player_ref.global_position, targets[0].global_position)

	# Lightning between subsequent targets (enemy to enemy)
	for i in range(targets.size() - 1):
		if is_instance_valid(targets[i]) and is_instance_valid(targets[i + 1]):
			_create_lightning_bolt(targets[i].global_position, targets[i + 1].global_position)

func _create_lightning_bolt(from: Vector2, to: Vector2):
	var tree = get_tree()
	if not tree:
		return
	var scene = tree.current_scene
	if not scene:
		return

	# Glow layer (outer)
	var glow_bolt = Line2D.new()
	glow_bolt.default_color = ELECTRIC_GLOW
	glow_bolt.width = 20.0
	glow_bolt.z_index = 99
	glow_bolt.top_level = true  # Use global coordinates
	scene.add_child(glow_bolt)

	# Core layer - brightest
	var core_bolt = Line2D.new()
	core_bolt.default_color = ELECTRIC_CORE
	core_bolt.width = 10.0
	core_bolt.z_index = 100
	core_bolt.top_level = true
	scene.add_child(core_bolt)

	# Inner white core
	var inner_bolt = Line2D.new()
	inner_bolt.default_color = Color(1.0, 1.0, 1.0, 1.0)
	inner_bolt.width = 4.0
	inner_bolt.z_index = 101
	inner_bolt.top_level = true
	scene.add_child(inner_bolt)

	# Create jagged lightning path
	var segments = 6
	var points = PackedVector2Array()
	points.append(from)

	var direction = (to - from).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)

	for i in range(1, segments):
		var t = float(i) / float(segments)
		var point = from.lerp(to, t)
		var offset = perpendicular * randf_range(-50, 50)
		points.append(point + offset)

	points.append(to)

	glow_bolt.points = points
	core_bolt.points = points
	inner_bolt.points = points

	# Impact spark at hit point
	_create_impact_spark(to)

	# Fade out using TweenHelper
	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(glow_bolt, "modulate:a", 0.0, 0.25)
	tween.tween_property(core_bolt, "modulate:a", 0.0, 0.2)
	tween.tween_property(inner_bolt, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(func():
		if is_instance_valid(glow_bolt):
			glow_bolt.queue_free()
		if is_instance_valid(core_bolt):
			core_bolt.queue_free()
		if is_instance_valid(inner_bolt):
			inner_bolt.queue_free()
	)

func _create_impact_spark(pos: Vector2):
	var tree = get_tree()
	if not tree:
		return
	var scene = tree.current_scene
	if not scene:
		return

	# Flash at hit point
	var flash = ColorRect.new()
	flash.size = Vector2(40, 40)
	flash.color = Color(1.0, 1.0, 1.0, 0.9)
	flash.pivot_offset = Vector2(20, 20)
	flash.z_index = 102
	scene.add_child(flash)
	flash.global_position = pos - Vector2(20, 20)

	var flash_tween = TweenHelper.new_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.12)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.12)
	flash_tween.chain().tween_callback(func():
		if is_instance_valid(flash):
			flash.queue_free()
	)

	# Sparks flying out
	for i in range(6):
		var spark = ColorRect.new()
		spark.size = Vector2(6, 14)
		spark.color = ELECTRIC_SPARK
		spark.pivot_offset = Vector2(3, 7)
		spark.z_index = 100
		scene.add_child(spark)
		spark.global_position = pos

		var angle = randf() * TAU
		var dir = Vector2.from_angle(angle)
		var end_pos = pos + dir * randf_range(30, 60)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", end_pos, 0.18)
		tween.tween_property(spark, "modulate:a", 0.0, 0.18)
		tween.tween_property(spark, "scale", Vector2(0.3, 0.3), 0.18)
		tween.chain().tween_callback(func():
			if is_instance_valid(spark):
				spark.queue_free()
		)

func _apply_stun_effect(target: Node2D):
	if not is_instance_valid(target):
		return

	# Brief electric overlay on enemy
	var original_modulate = target.modulate
	target.modulate = Color(0.5, 0.8, 1.0)

	# Small sparks on stunned enemy
	var tree = get_tree()
	if tree and tree.current_scene:
		for i in range(3):
			var spark = ColorRect.new()
			spark.size = Vector2(4, 8)
			spark.color = ELECTRIC_SPARK
			spark.pivot_offset = Vector2(2, 4)
			spark.z_index = 100
			tree.current_scene.add_child(spark)
			spark.global_position = target.global_position + Vector2(randf_range(-15, 15), randf_range(-20, 10))

			var tween = TweenHelper.new_tween()
			tween.set_parallel(true)
			tween.tween_property(spark, "global_position:y", spark.global_position.y - 25, 0.25)
			tween.tween_property(spark, "modulate:a", 0.0, 0.25)
			tween.chain().tween_callback(func():
				if is_instance_valid(spark):
					spark.queue_free()
			)

	# Reset color after stun
	var reset_tween = TweenHelper.new_tween()
	reset_tween.tween_interval(stun_duration)
	reset_tween.tween_callback(func():
		if is_instance_valid(target):
			target.modulate = original_modulate
	)
