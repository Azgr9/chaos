# SCRIPT: ChainLightningSkill.gd
# LightningStaff's Chain Lightning skill - zaps multiple enemies
# LOCATION: res://Scenes/Weapons/LightningStaff/spells/ChainLightningSkill.gd

extends Node2D

# Chain lightning settings
@export var chain_lightning_duration: float = 3.0
@export var chain_range: float = 600.0
@export var chain_damage: float = 8.0
@export var max_chains: int = 3
@export var zap_interval: float = 0.3

# Colors
const ELECTRIC_CORE: Color = Color(0.4, 0.9, 1.0)
const ELECTRIC_GLOW: Color = Color(0.0, 1.0, 1.0, 0.8)

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

	# Make sure skill is visible above everything
	z_index = 100

	_setup_timers()
	_activate_chain_lightning()

func _setup_timers():
	# Duration timer - how long the ability lasts
	ability_duration_timer = Timer.new()
	ability_duration_timer.one_shot = true
	ability_duration_timer.timeout.connect(_on_ability_duration_finished)
	add_child(ability_duration_timer)

	# Zap timer - interval between chain lightning strikes
	zap_timer = Timer.new()
	zap_timer.one_shot = false
	zap_timer.timeout.connect(_perform_chain_lightning)
	add_child(zap_timer)

func _activate_chain_lightning():
	ability_active = true

	# Start timers
	ability_duration_timer.start(chain_lightning_duration)
	zap_timer.start(zap_interval)

	# Do first zap immediately
	_perform_chain_lightning()

func _on_ability_duration_finished():
	ability_active = false
	zap_timer.stop()
	skill_completed.emit()
	queue_free()

func _perform_chain_lightning():
	if not ability_active or not player_ref:
		return

	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	# Find closest enemy within range
	var closest_enemy = _find_closest_enemy(player_ref.global_position, enemies, [])
	if not closest_enemy:
		return

	# Build chain of targets
	var chain_targets = [closest_enemy]
	var current_target = closest_enemy

	for i in range(max_chains - 1):
		var next_target = _find_closest_enemy(current_target.global_position, enemies, chain_targets)
		if next_target:
			chain_targets.append(next_target)
			current_target = next_target
		else:
			break

	# Damage all targets
	for target in chain_targets:
		if is_instance_valid(target) and target.has_method("take_damage"):
			var final_damage = chain_damage * damage_multiplier
			target.take_damage(final_damage, player_ref.global_position, 150.0, 0.1, player_ref, damage_type)
			dealt_damage.emit(target, final_damage)

	# Draw lightning visual
	_draw_lightning_chain(chain_targets)

func _find_closest_enemy(from_position: Vector2, enemies: Array, exclude: Array) -> Node2D:
	var closest: Node2D = null
	var closest_dist = chain_range

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy in exclude:
			continue
		# Skip converted minions
		if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
			continue

		var dist = from_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy

	return closest

func _draw_lightning_chain(targets: Array):
	if targets.is_empty() or not player_ref:
		return

	# Lightning from player to first target
	_create_lightning_bolt(player_ref.global_position, targets[0].global_position)

	# Lightning between subsequent targets
	for i in range(targets.size() - 1):
		if is_instance_valid(targets[i]) and is_instance_valid(targets[i + 1]):
			_create_lightning_bolt(targets[i].global_position, targets[i + 1].global_position)

func _create_lightning_bolt(from: Vector2, to: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Outer glow bolt (wider, more transparent)
	var glow_bolt = Line2D.new()
	scene.add_child(glow_bolt)
	glow_bolt.default_color = Color(0.4, 0.9, 1.0, 0.4)
	glow_bolt.width = 20.0
	glow_bolt.z_index = 99

	# Main bolt
	var bolt = Line2D.new()
	scene.add_child(bolt)
	bolt.default_color = ELECTRIC_GLOW
	bolt.width = 10.0
	bolt.z_index = 100

	# Core bolt (brightest)
	var core_bolt = Line2D.new()
	scene.add_child(core_bolt)
	core_bolt.default_color = Color(1.0, 1.0, 0.9, 1.0)
	core_bolt.width = 4.0
	core_bolt.z_index = 101

	# Create jagged lightning
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
	bolt.points = points
	glow_bolt.points = points
	core_bolt.points = points

	# Create spark at hit point
	_create_lightning_spark(to)

	# Fade out all bolts
	var tween = scene.create_tween()
	if tween:
		tween.set_parallel(true)
		tween.tween_property(bolt, "modulate:a", 0.0, 0.15)
		tween.tween_property(glow_bolt, "modulate:a", 0.0, 0.15)
		tween.tween_property(core_bolt, "modulate:a", 0.0, 0.15)
		tween.tween_callback(bolt.queue_free)
		tween.tween_callback(glow_bolt.queue_free)
		tween.tween_callback(core_bolt.queue_free)

func _create_lightning_spark(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Bright spark at hit location
	for i in range(6):
		var spark = ColorRect.new()
		spark.size = Vector2(6, 12)
		spark.color = Color(1.0, 1.0, 0.7, 1.0)
		spark.pivot_offset = Vector2(3, 6)
		spark.z_index = 100
		scene.add_child(spark)
		spark.global_position = pos

		var angle = randf() * TAU
		var dir = Vector2.from_angle(angle)

		var tween = scene.create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(spark, "global_position", pos + dir * randf_range(20, 40), 0.15)
			tween.tween_property(spark, "modulate:a", 0.0, 0.15)
			tween.tween_property(spark, "scale", Vector2(0.3, 0.3), 0.15)
			tween.tween_callback(spark.queue_free)
