# SCRIPT: LightningStaff.gd
# ATTACH TO: LightningStaff (Node2D) root node in LightningStaff.tscn
# LOCATION: res://Scripts/Weapons/LightningStaff.gd
# Electric staff with crackling lightning bolt projectiles

class_name LightningStaff
extends MagicWeapon

# ============================================
# PROJECTILE COLORS
# ============================================
const ELECTRIC_CORE: Color = Color(0.4, 0.9, 1.0)  # Bright electric blue
const ELECTRIC_GLOW: Color = Color(0.0, 1.0, 1.0, 0.8)  # Cyan
const ELECTRIC_SPARK: Color = Color(1.0, 1.0, 0.6)  # Yellow-white sparks

# ============================================
# CHAIN LIGHTNING SETTINGS
# ============================================
@export_group("Chain Lightning")
@export var chain_lightning_duration: float = 3.0
@export var chain_range: float = 600.0
@export var chain_damage: float = 8.0
@export var max_chains: int = 3
@export var zap_interval: float = 0.3

# ============================================
# STATE
# ============================================
var ability_active: bool = false

# Timers (set up in _weapon_ready)
var ability_duration_timer: Timer
var zap_timer: Timer

func _weapon_ready():
	# LightningStaff - fast, electric damage
	attack_cooldown = 0.22  # Fast attack speed - lightning is quick
	projectile_spread = 5.0
	multi_shot = 1
	damage = 11.0  # Slightly lower damage for faster speed
	damage_type = DamageTypes.Type.ELECTRIC  # Applies SHOCK status effect
	staff_color = Color("#4488ff")  # Electric blue

	# Attack Speed Limits (fastest magic staff)
	max_attacks_per_second = 4.5  # Very fast casting
	min_cooldown = 0.14  # Can cast extremely fast

	# Override skill cooldown
	skill_cooldown = 8.0

	# Set up ability timers (replacing while-loop)
	_setup_ability_timers()

func _setup_ability_timers():
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

func _get_beam_color() -> Color:
	return Color("#00ffff")  # Cyan

func _get_beam_glow_color() -> Color:
	return Color("#66ccff", 0.6)  # Light blue

func _get_projectile_color() -> Color:
	return ELECTRIC_CORE

func _customize_projectile(projectile: Node2D):
	# Crackling electric bolt
	if projectile.has_node("Sprite"):
		var sprite_node = projectile.get_node("Sprite")
		sprite_node.color = ELECTRIC_CORE
		sprite_node.size = Vector2(12, 18)  # Elongated bolt shape

	# Add electric crackling effect
	_add_electric_trail(projectile)

func _add_electric_trail(projectile: Node2D):
	var timer = Timer.new()
	timer.wait_time = 0.03
	timer.one_shot = false
	projectile.add_child(timer)

	timer.timeout.connect(func():
		if not is_instance_valid(projectile):
			timer.stop()
			timer.queue_free()
			return

		# Check if self (LightningStaff) is still valid
		if not is_instance_valid(self):
			timer.stop()
			timer.queue_free()
			return

		# Electric spark particle
		var spark = ColorRect.new()
		spark.size = Vector2(4, 8)
		spark.color = ELECTRIC_SPARK if randf() > 0.5 else ELECTRIC_GLOW
		spark.pivot_offset = Vector2(2, 4)
		get_tree().current_scene.add_child(spark)
		spark.global_position = projectile.global_position
		spark.rotation = randf() * TAU

		# Small arc/zap away from projectile
		var offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", projectile.global_position + offset, 0.1)
		tween.tween_property(spark, "modulate:a", 0.0, 0.1)
		tween.tween_property(spark, "scale", Vector2(0.3, 0.3), 0.1)
		tween.tween_callback(spark.queue_free)

		# Occasional mini-bolt branching off
		if randf() > 0.7:
			_create_mini_bolt(projectile.global_position)
	)
	timer.start()

func _create_mini_bolt(pos: Vector2):
	var bolt = Line2D.new()
	get_tree().current_scene.add_child(bolt)
	bolt.default_color = ELECTRIC_GLOW
	bolt.width = 2.0

	var end_pos = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	var mid_pos = pos.lerp(end_pos, 0.5) + Vector2(randf_range(-8, 8), randf_range(-8, 8))

	bolt.points = PackedVector2Array([pos, mid_pos, end_pos])

	var tween = TweenHelper.new_tween()
	tween.tween_property(bolt, "modulate:a", 0.0, 0.08)
	tween.tween_callback(bolt.queue_free)

# ============================================
# CHAIN LIGHTNING SKILL (Timer-based)
# ============================================
func _perform_skill() -> bool:
	if ability_active:
		return false

	ability_active = true

	# Visual feedback
	sprite.color = Color("#ffff00")  # Bright yellow during ability

	# Start timers
	ability_duration_timer.start(chain_lightning_duration)
	zap_timer.start(zap_interval)

	# Do first zap immediately
	_perform_chain_lightning()

	return true

func _on_ability_duration_finished():
	ability_active = false
	zap_timer.stop()
	sprite.color = staff_color

func _perform_chain_lightning():
	if not ability_active or not player_reference:
		return

	var enemies = _get_enemies()
	if enemies.is_empty():
		return

	# Find closest enemy within range
	var closest_enemy = _find_closest_enemy(player_reference.global_position, enemies, [])
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
	var attacker = player_reference if is_instance_valid(player_reference) else null
	var origin = player_reference.global_position if attacker else Vector2.ZERO
	for target in chain_targets:
		if is_instance_valid(target) and target.has_method("take_damage"):
			var final_damage = chain_damage * damage_multiplier
			target.take_damage(final_damage, origin, 150.0, 0.1, attacker, damage_type)

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

		var dist = from_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy

	return closest

func _draw_lightning_chain(targets: Array):
	if targets.is_empty() or not player_reference:
		return

	# Lightning from player to first target
	_create_lightning_bolt(player_reference.global_position, targets[0].global_position)

	# Lightning between subsequent targets
	for i in range(targets.size() - 1):
		if is_instance_valid(targets[i]) and is_instance_valid(targets[i + 1]):
			_create_lightning_bolt(targets[i].global_position, targets[i + 1].global_position)

func _create_lightning_bolt(from: Vector2, to: Vector2):
	var bolt = Line2D.new()
	get_tree().root.add_child(bolt)

	bolt.default_color = Color("#00ffff")
	bolt.width = 8.0

	# Create jagged lightning
	var segments = 5
	var points = PackedVector2Array()
	points.append(from)

	var direction = (to - from).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)

	for i in range(1, segments):
		var t = float(i) / float(segments)
		var point = from.lerp(to, t)
		var offset = perpendicular * randf_range(-40, 40)
		points.append(point + offset)

	points.append(to)
	bolt.points = points

	# Fade out
	var tween = TweenHelper.new_tween()
	tween.tween_property(bolt, "modulate:a", 0.0, 0.2)
	tween.tween_callback(bolt.queue_free)

# ============================================
# ATTACK ANIMATION OVERRIDE
# ============================================
func _play_attack_animation():
	# Purple/blue muzzle flash for lightning
	muzzle_flash.modulate.a = 1.0
	muzzle_flash.color = Color("#66ccff")
	var flash_tween = TweenHelper.new_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.1)

	# Staff recoil
	var recoil_tween = TweenHelper.new_tween()
	recoil_tween.tween_property(self, "position:x", -12, 0.05)
	recoil_tween.tween_property(self, "position:x", 0, 0.1)

	# Electric blue glow
	sprite.color = Color("#66ccff")
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self) and sprite and not ability_active:
		sprite.color = staff_color
