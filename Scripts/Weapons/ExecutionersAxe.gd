# SCRIPT: ExecutionersAxe.gd
# ATTACH TO: ExecutionersAxe (Node2D) root node in ExecutionersAxe.tscn
# LOCATION: res://Scripts/Weapons/ExecutionersAxe.gd
# Heavy, slow, high damage axe with Guillotine Drop skill

class_name ExecutionersAxe
extends MeleeWeapon

# ============================================
# AXE-SPECIFIC SETTINGS
# ============================================
const GUILLOTINE_DROP_SCENE = preload("res://Scenes/Weapons/GuillotineDrop.tscn")

# Visual colors
const AXE_BLADE_COLOR: Color = Color(0.7, 0.7, 0.75)  # Polished steel blade
const AXE_HANDLE_COLOR: Color = Color(0.35, 0.2, 0.1)  # Dark wood handle
const AXE_BLOOD_COLOR: Color = Color(0.6, 0.1, 0.1)  # Blood red accent
const AXE_GLOW_COLOR: Color = Color(1.0, 0.3, 0.1)  # Orange glow on power attacks

# Trail settings
var swing_trail_enabled: bool = true
var trail_particles: Array = []

func _weapon_ready():
	# Heavy axe stats - 2.5x BasicSword damage, but slower
	damage = 25.0
	attack_duration = 0.45  # Slow swing
	attack_cooldown = 0.6   # Long recovery
	swing_arc = 120.0       # Narrower arc
	weapon_length = 90.0    # Slightly longer reach
	weapon_color = AXE_BLADE_COLOR
	skill_cooldown = 12.0

	# Cone Hitbox - Now configured via @export in scene inspector
	# attack_range = 125.0  # Good reach for cleave
	# attack_cone_angle = 110.0  # Wide cleaving arc

	# Attack Speed Limits (slow heavy weapon)
	max_attacks_per_second = 2.0  # Slow but powerful
	min_cooldown = 0.35  # Cannot swing faster than this

	# Idle appearance
	idle_rotation = 50.0
	idle_scale = Vector2(0.7, 0.7)

	# Heavier knockback
	base_knockback = 500.0
	finisher_knockback = 1000.0

	# Slower combo
	combo_finisher_multiplier = 1.8  # Higher finisher bonus for heavy weapon
	combo_window = 2.0  # Longer window for slow weapon

func _get_attack_pattern(attack_index: int) -> String:
	# Executioner's Axe: overhead -> overhead -> slam (all vertical chops)
	match attack_index:
		1: return "overhead"
		2: return "overhead"
		3: return "slam"
		_: return "overhead"

func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	# Kill existing tween
	if active_attack_tween:
		active_attack_tween.kill()

	var is_finisher = is_combo_finisher()

	# Set attack color
	if is_finisher:
		sprite.color = Color.GOLD
	elif is_dash_attack:
		sprite.color = Color.CYAN

	match pattern:
		"overhead":
			_animate_overhead_chop(duration, is_dash_attack)
		"slam":
			_animate_slam(duration, is_dash_attack)
		_:
			_animate_overhead_chop(duration, is_dash_attack)

func _animate_overhead_chop(duration: float, _is_dash_attack: bool):
	active_attack_tween = TweenHelper.new_tween()

	# Get the base angle from attack direction
	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	# Vertical chop: raise high, slam down
	var raise_angle = base_angle - 90  # Raised above head
	var chop_angle = base_angle + 30   # Follow through down

	pivot.rotation = deg_to_rad(raise_angle)
	pivot.position = Vector2.ZERO
	sprite.scale = Vector2(1.1, 1.1)

	# Wind up - raise axe with glow
	_create_charge_glow()
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(raise_angle - 20), duration * 0.25)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(is_combo_finisher(), false))

	# Start trail during swing
	active_attack_tween.tween_callback(_start_swing_trail)

	# Chop down - powerful swing
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(chop_angle), duration * 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Impact spark on hit
	active_attack_tween.tween_callback(_create_chop_sparks)

	# Follow through
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(chop_angle + 10), duration * 0.25)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _animate_slam(duration: float, _is_dash_attack: bool):
	# Finisher slam - bigger, more dramatic
	active_attack_tween = TweenHelper.new_tween()

	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	# High raise for slam
	var raise_angle = base_angle - 120
	var slam_angle = base_angle + 45

	pivot.rotation = deg_to_rad(raise_angle)
	pivot.position = Vector2.ZERO
	sprite.scale = Vector2(1.4, 1.4)  # Scale up big for finisher
	sprite.color = AXE_GLOW_COLOR  # Glow orange

	# Intense charge glow
	_create_finisher_charge_effect()

	# Long wind up with menacing pause
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(raise_angle - 30), duration * 0.3)
	active_attack_tween.tween_interval(duration * 0.05)  # Brief tension pause

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(true, false))
	active_attack_tween.tween_callback(_start_swing_trail)

	# Massive slam - FAST
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(slam_angle), duration * 0.2)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	# Ground impact - brief pause
	active_attack_tween.tween_interval(duration * 0.1)

	# Create ground crack effect on slam
	active_attack_tween.tween_callback(_create_slam_impact)

	# Recovery
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(slam_angle + 5), duration * 0.15)
	active_attack_tween.tween_property(sprite, "color", weapon_color, duration * 0.15)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _create_slam_impact():
	# Ground crack visual
	if not player_reference:
		return

	var impact_pos = player_reference.global_position + current_attack_direction * 60

	# Multiple shockwave rings for dramatic effect
	for i in range(3):
		_create_shockwave_ring(impact_pos, i * 0.08, 1.0 - i * 0.2)

	# Ground cracks radiating outward
	_create_ground_cracks(impact_pos)

	# Debris flying up
	_create_debris_particles(impact_pos, 10)

	# Sparks
	_create_impact_sparks(impact_pos, 8)

	# Screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.5)

func _create_shockwave_ring(pos: Vector2, delay: float, alpha: float):
	await get_tree().create_timer(delay).timeout

	# Check validity after await
	if not is_instance_valid(self):
		return

	var ring = ColorRect.new()
	ring.size = Vector2(40, 40)
	ring.color = Color(AXE_GLOW_COLOR.r, AXE_GLOW_COLOR.g, AXE_GLOW_COLOR.b, alpha)
	ring.pivot_offset = Vector2(20, 20)
	get_tree().current_scene.add_child(ring)
	ring.global_position = pos - Vector2(20, 20)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(5, 5), 0.35)
	tween.tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.tween_callback(ring.queue_free)

func _create_ground_cracks(pos: Vector2):
	for i in range(8):
		var crack = ColorRect.new()
		crack.size = Vector2(randf_range(60, 100), 4)
		crack.color = Color(0.3, 0.2, 0.15, 0.9)
		crack.pivot_offset = Vector2(0, 2)
		crack.rotation = (TAU / 8) * i + randf_range(-0.2, 0.2)
		get_tree().current_scene.add_child(crack)
		crack.global_position = pos
		crack.scale = Vector2(0, 1)

		var tween = TweenHelper.new_tween()
		tween.tween_property(crack, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.3)
		tween.tween_property(crack, "modulate:a", 0.0, 0.4)
		tween.tween_callback(crack.queue_free)

func _create_debris_particles(pos: Vector2, count: int):
	for i in range(count):
		var debris = ColorRect.new()
		debris.size = Vector2(randf_range(8, 16), randf_range(8, 16))
		debris.color = Color(0.4, 0.3, 0.2, 1.0)
		debris.pivot_offset = debris.size / 2
		get_tree().current_scene.add_child(debris)
		debris.global_position = pos + Vector2(randf_range(-20, 20), randf_range(-10, 10))

		var angle = randf_range(-PI * 0.8, -PI * 0.2)  # Upward arc
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(80, 150)
		var end_pos = debris.global_position + dir * dist

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(debris, "global_position", end_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(debris, "global_position:y", end_pos.y + 100, 0.5).set_delay(0.25)
		tween.tween_property(debris, "rotation", randf_range(-TAU, TAU), 0.5)
		tween.tween_property(debris, "modulate:a", 0.0, 0.5)
		tween.tween_callback(debris.queue_free)

func _create_impact_sparks(pos: Vector2, count: int):
	for i in range(count):
		var spark = ColorRect.new()
		spark.size = Vector2(6, 12)
		spark.color = Color(1.0, 0.8, 0.3, 1.0)  # Bright yellow-orange
		spark.pivot_offset = Vector2(3, 6)
		get_tree().current_scene.add_child(spark)
		spark.global_position = pos

		var angle = randf_range(0, TAU)
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(40, 100)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", pos + dir * dist, 0.25)
		tween.tween_property(spark, "scale", Vector2(0.2, 0.2), 0.25)
		tween.tween_property(spark, "modulate:a", 0.0, 0.25)
		tween.tween_callback(spark.queue_free)

# ============================================
# VISUAL EFFECT HELPERS
# ============================================
func _create_charge_glow():
	if not player_reference:
		return

	# Brief glow on weapon during windup
	var glow = ColorRect.new()
	glow.size = Vector2(30, 60)
	glow.color = Color(AXE_GLOW_COLOR.r, AXE_GLOW_COLOR.g, AXE_GLOW_COLOR.b, 0.4)
	glow.pivot_offset = Vector2(15, 30)
	add_child(glow)
	glow.position = Vector2(-15, -30)

	var tween = TweenHelper.new_tween()
	tween.tween_property(glow, "modulate:a", 0.0, 0.3)
	tween.tween_callback(glow.queue_free)

func _create_finisher_charge_effect():
	if not player_reference:
		return

	# Intense particles gathering around axe
	for i in range(8):
		var particle = ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.color = AXE_GLOW_COLOR
		particle.pivot_offset = Vector2(4, 4)
		get_tree().current_scene.add_child(particle)

		# Start from random position around player
		var angle = (TAU / 8) * i
		var start_pos = player_reference.global_position + Vector2.from_angle(angle) * 80
		particle.global_position = start_pos

		# Converge to axe position
		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", global_position, 0.25)
		tween.tween_property(particle, "scale", Vector2(0.3, 0.3), 0.25)
		tween.tween_callback(particle.queue_free)

func _start_swing_trail():
	# Create trail particles during swing
	_spawn_trail_particle()

func _spawn_trail_particle():
	if not player_reference:
		return

	var trail = ColorRect.new()
	trail.size = Vector2(20, 40)
	trail.color = Color(AXE_GLOW_COLOR.r, AXE_GLOW_COLOR.g, AXE_GLOW_COLOR.b, 0.6)
	trail.pivot_offset = Vector2(10, 20)
	get_tree().current_scene.add_child(trail)
	trail.global_position = global_position
	trail.rotation = pivot.rotation

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "modulate:a", 0.0, 0.2)
	tween.tween_property(trail, "scale", Vector2(0.5, 1.5), 0.2)
	tween.tween_callback(trail.queue_free)

func _create_chop_sparks():
	if not player_reference:
		return

	var spark_pos = player_reference.global_position + current_attack_direction * 70

	for i in range(5):
		var spark = ColorRect.new()
		spark.size = Vector2(4, 8)
		spark.color = Color(1.0, 0.9, 0.5, 1.0)
		spark.pivot_offset = Vector2(2, 4)
		get_tree().current_scene.add_child(spark)
		spark.global_position = spark_pos

		var angle = randf_range(-PI/3, PI/3) + current_attack_direction.angle()
		var dir = Vector2.from_angle(angle)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", spark_pos + dir * randf_range(30, 60), 0.15)
		tween.tween_property(spark, "modulate:a", 0.0, 0.15)
		tween.tween_callback(spark.queue_free)

# ============================================
# SKILL - GUILLOTINE DROP
# ============================================

## GuillotineDrop manages its own invulnerability during the leap
func _is_async_skill() -> bool:
	return true

func _perform_skill() -> bool:
	# Guillotine Drop skill - leap forward, deal 3x damage in small AoE
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false

	var guillotine = GUILLOTINE_DROP_SCENE.instantiate()
	get_tree().current_scene.add_child(guillotine)

	var skill_damage = damage * 3.0 * damage_multiplier
	var direction = (player.get_global_mouse_position() - player.global_position).normalized()
	guillotine.initialize(player, direction, skill_damage)

	if guillotine.has_signal("dealt_damage"):
		var axe_ref = weakref(self)
		guillotine.dealt_damage.connect(func(target, dmg):
			var axe = axe_ref.get_ref()
			if axe:
				axe.dealt_damage.emit(target, dmg)
		)

	return true

func _on_combo_finisher_hit(_target: Node2D):
	# Extra screen shake on finisher hit
	if DamageNumberManager:
		DamageNumberManager.shake(0.4)

func _get_hit_color(combo_finisher: bool, dash_attack: bool, crit: bool) -> Color:
	if crit:
		return Color.RED
	elif combo_finisher:
		return AXE_GLOW_COLOR
	elif dash_attack:
		return Color.CYAN
	return weapon_color
