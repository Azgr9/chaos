# SCRIPT: ExecutionersAxe.gd
# ATTACH TO: ExecutionersAxe (Node2D) root node in ExecutionersAxe.tscn
# LOCATION: res://Scripts/Weapons/ExecutionersAxe.gd
# Heavy, slow, high damage axe with Guillotine Drop skill

class_name ExecutionersAxe
extends MeleeWeapon

# ============================================
# AXE-SPECIFIC SETTINGS
# ============================================
const SKILL_SCENE = preload("res://Scenes/Weapons/ExecutionersAxe/ExecutionersAxeSkill.tscn")

# Sprite2D texture for the axe visual (ColorRect "Sprite" is hidden for base class compatibility)
@onready var axe_sprite: Sprite2D = $Pivot/AxeTexture

# Visual colors
const AXE_BLADE_COLOR: Color = Color(0.7, 0.7, 0.75)  # Polished steel blade
const AXE_HANDLE_COLOR: Color = Color(0.35, 0.2, 0.1)  # Dark wood handle
const AXE_BLOOD_COLOR: Color = Color(0.6, 0.1, 0.1)  # Blood red accent
const AXE_GLOW_COLOR: Color = Color(1.0, 0.3, 0.1)  # Orange glow on power attacks
const AXE_FIRE_COLOR: Color = Color(1.0, 0.6, 0.2)  # Fire accent

# Shaders
var swing_shader: Shader = preload("res://Shaders/Weapons/SwingTrail.gdshader")
var shockwave_shader: Shader = preload("res://Shaders/Weapons/ImpactShockwave.gdshader")
var energy_shader: Shader = preload("res://Shaders/Weapons/EnergyGlow.gdshader")
var crack_shader: Shader = preload("res://Shaders/Weapons/GroundCrack.gdshader")

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

	# Idle appearance - Axe resting on shoulder
	idle_rotation = -30.0  # Angled back over shoulder
	idle_position = Vector2(-5, -15)  # Up and slightly back (shoulder position)
	idle_scale = Vector2(1.05, 1.05)  # Base ColorRect idle scale (hidden)

	# Heavier knockback
	base_knockback = 500.0
	finisher_knockback = 1000.0

	# Slower combo
	combo_finisher_multiplier = 1.8  # Higher finisher bonus for heavy weapon
	combo_window = 2.0  # Longer window for slow weapon

func _get_attack_pattern(attack_index: int) -> String:
	# Executioner's Axe: slash -> slash_reverse -> overhead slam
	match attack_index:
		1: return "slash"
		2: return "slash_reverse"
		3: return "slam"
		_: return "slash"

func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	# Kill existing tween
	if active_attack_tween:
		active_attack_tween.kill()

	var is_finisher = is_combo_finisher()

	# Set attack color (use modulate for Sprite2D)
	if is_finisher:
		axe_sprite.modulate = Color.GOLD
	elif is_dash_attack:
		axe_sprite.modulate = Color.CYAN

	match pattern:
		"slash":
			_animate_slash(duration, is_dash_attack, false)
		"slash_reverse":
			_animate_slash(duration, is_dash_attack, true)
		"slam":
			_animate_slam(duration, is_dash_attack)
		_:
			_animate_slash(duration, is_dash_attack, false)

# Horizontal cleave - wide sweeping attack
func _animate_slash(duration: float, _is_dash_attack: bool, reverse: bool):
	active_attack_tween = TweenHelper.new_tween()

	# Get the base angle from attack direction
	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	# Wide horizontal arc for axe cleave
	var half_arc = 70.0
	var start_angle: float
	var end_angle: float

	# Flip axe blade direction based on swing direction
	# Blade should always face the direction of the swing
	var scale_x: float

	if reverse:
		# Right to left sweep - flip blade to face left
		start_angle = base_angle + half_arc
		end_angle = base_angle - half_arc
		scale_x = 1.1  # Positive = blade faces left
	else:
		# Left to right sweep - blade faces right
		start_angle = base_angle - half_arc
		end_angle = base_angle + half_arc
		scale_x = -1.1  # Negative = blade faces right

	pivot.rotation = deg_to_rad(start_angle)
	pivot.position = Vector2.ZERO
	axe_sprite.scale = Vector2(scale_x, 1.1)

	# Wind up - pull back slightly
	var windup_angle = start_angle + (-15 if not reverse else 15)
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(windup_angle), duration * 0.2)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(is_combo_finisher(), false))

	# Start trail during swing
	active_attack_tween.tween_callback(_start_swing_trail)

	# Main cleave - powerful horizontal sweep
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(end_angle), duration * 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Impact spark
	active_attack_tween.tween_callback(_create_chop_sparks)

	# Follow through
	var followthrough_angle = end_angle + (15 if not reverse else -15)
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(followthrough_angle), duration * 0.2)

	active_attack_tween.tween_callback(_disable_hitbox)
	active_attack_tween.tween_callback(_reset_axe_sprite)
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
	axe_sprite.scale = Vector2(-1.4, 1.4)  # -1 base * 1.4 finisher boost (flipped)
	axe_sprite.modulate = AXE_GLOW_COLOR  # Glow orange

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
	active_attack_tween.tween_property(axe_sprite, "modulate", Color.WHITE, duration * 0.15)

	active_attack_tween.tween_callback(_disable_hitbox)
	active_attack_tween.tween_callback(_reset_axe_sprite)
	_tween_to_idle(active_attack_tween)

func _reset_axe_sprite():
	# Reset axe sprite to base scale and color after attack
	if axe_sprite:
		axe_sprite.scale = Vector2(-1, 1)  # Flipped horizontally (base scale)
		axe_sprite.modulate = Color.WHITE

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

	var scene = get_tree().current_scene
	if not scene:
		return

	# Shader-based shockwave
	var ring = ColorRect.new()
	ring.size = Vector2(200, 200)
	ring.pivot_offset = Vector2(100, 100)
	ring.global_position = pos - Vector2(100, 100)

	var mat = ShaderMaterial.new()
	mat.shader = shockwave_shader
	mat.set_shader_parameter("wave_color", Color(AXE_GLOW_COLOR.r, AXE_GLOW_COLOR.g, AXE_GLOW_COLOR.b, alpha))
	mat.set_shader_parameter("ring_thickness", 0.12)
	mat.set_shader_parameter("inner_glow", 1.5)
	mat.set_shader_parameter("progress", 0.0)
	ring.material = mat

	scene.add_child(ring)

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.4)
	tween.tween_callback(ring.queue_free)

func _create_ground_cracks(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	for i in range(10):
		var crack = ColorRect.new()
		crack.size = Vector2(randf_range(80, 130), 10)
		crack.pivot_offset = Vector2(0, 5)
		crack.rotation = (TAU / 10) * i + randf_range(-0.15, 0.15)
		crack.global_position = pos

		var mat = ShaderMaterial.new()
		mat.shader = crack_shader
		mat.set_shader_parameter("crack_color", Color(0.25, 0.15, 0.1, 0.95))
		mat.set_shader_parameter("glow_color", AXE_FIRE_COLOR)
		mat.set_shader_parameter("crack_width", 0.1)
		mat.set_shader_parameter("jagged_amount", 0.2)
		mat.set_shader_parameter("progress", 0.0)
		crack.material = mat

		scene.add_child(crack)

		var tween = TweenHelper.new_tween()
		tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.6)
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

	# Shader-based energy glow on weapon
	var glow = ColorRect.new()
	glow.size = Vector2(80, 80)
	glow.pivot_offset = Vector2(40, 40)
	add_child(glow)
	glow.position = Vector2(-40, -60)

	var mat = ShaderMaterial.new()
	mat.shader = energy_shader
	mat.set_shader_parameter("energy_color", AXE_GLOW_COLOR)
	mat.set_shader_parameter("core_color", AXE_FIRE_COLOR)
	mat.set_shader_parameter("pulse_speed", 12.0)
	mat.set_shader_parameter("pulse_intensity", 0.4)
	mat.set_shader_parameter("glow_size", 1.2)
	mat.set_shader_parameter("progress", 0.0)
	glow.material = mat

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.35)
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

	var scene = get_tree().current_scene
	if not scene:
		return

	# Shader-based swing trail
	var trail = ColorRect.new()
	trail.size = Vector2(weapon_length * 0.9, 35)
	trail.pivot_offset = Vector2(0, 17.5)
	trail.global_position = global_position
	trail.rotation = pivot.rotation

	var mat = ShaderMaterial.new()
	mat.shader = swing_shader
	mat.set_shader_parameter("trail_color", Color(AXE_GLOW_COLOR.r, AXE_GLOW_COLOR.g, AXE_GLOW_COLOR.b, 0.7))
	mat.set_shader_parameter("glow_color", AXE_FIRE_COLOR)
	mat.set_shader_parameter("glow_intensity", 2.0)
	mat.set_shader_parameter("taper_amount", 0.6)
	mat.set_shader_parameter("progress", 0.0)
	trail.material = mat

	scene.add_child(trail)

	var tween = TweenHelper.new_tween()
	tween.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.2)
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

	var skill_instance = SKILL_SCENE.instantiate()
	get_tree().current_scene.add_child(skill_instance)

	var skill_damage = damage * 3.0 * damage_multiplier
	var direction = (player.get_global_mouse_position() - player.global_position).normalized()
	skill_instance.initialize(player, direction, skill_damage)

	if skill_instance.has_signal("dealt_damage"):
		var axe_ref = weakref(self)
		skill_instance.dealt_damage.connect(func(target, dmg):
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
