# SCRIPT: GuillotineDrop.gd
# ATTACH TO: GuillotineDrop (Node2D) root node in GuillotineDrop.tscn
# LOCATION: res://Scripts/Weapons/GuillotineDrop.gd
# Executioner's Axe skill - leap forward, deal 3x damage in small AoE

extends Node2D

@onready var hit_box: Area2D = $HitBox
@onready var visual: Node2D = $Visual
@onready var axe_visual: ColorRect = $Visual/Axe

const LEAP_DISTANCE: float = 250.0  # How far to leap (increased)
const LEAP_DURATION: float = 0.4
const IMPACT_RADIUS: float = 100.0  # Bigger impact area

# Visual colors
const AXE_GLOW_COLOR: Color = Color(1.0, 0.3, 0.1)
const BLOOD_COLOR: Color = Color(0.6, 0.1, 0.1)
const SPARK_COLOR: Color = Color(1.0, 0.8, 0.3)

var damage: float = 75.0
var hits_this_slam: Array = []
var player_ref: Node2D = null
var leap_direction: Vector2 = Vector2.RIGHT

signal dealt_damage(target: Node2D, damage: float)

func _ready():
	# Connect hit detection
	hit_box.area_entered.connect(_on_hit_box_area_entered)
	hit_box.body_entered.connect(_on_hit_box_body_entered)

	# Disable hitbox until impact
	$HitBox/CollisionShape2D.disabled = true

func initialize(player: Node2D, direction: Vector2, slam_damage: float):
	player_ref = player
	damage = slam_damage
	leap_direction = direction.normalized()

	# Start at player position
	global_position = player.global_position

	# Begin the leap animation
	_perform_leap()

func _perform_leap():
	# Make player invulnerable during leap
	if player_ref and player_ref.has_method("set_invulnerable"):
		player_ref.set_invulnerable(true)

	# Start position
	var start_pos = global_position
	var end_pos = start_pos + leap_direction * LEAP_DISTANCE

	# Initial state - axe raised and glowing
	visual.scale = Vector2(1.5, 1.5)
	modulate.a = 1.0
	axe_visual.rotation = deg_to_rad(-60)  # Raised high
	axe_visual.color = AXE_GLOW_COLOR

	# Create leap trail effect
	_create_leap_trail(start_pos, end_pos)

	# Create anticipation effect
	_create_windup_effect()

	var tween = TweenHelper.new_tween()

	# Brief pause for drama
	tween.tween_interval(0.1)

	# Arc upward first, then down - parabolic leap
	var mid_pos = start_pos.lerp(end_pos, 0.5) + Vector2(0, -80)  # Peak of arc

	# First half - rise up
	tween.tween_property(self, "global_position", mid_pos, LEAP_DURATION * 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Keep axe raised during rise
	tween.parallel().tween_property(axe_visual, "rotation", deg_to_rad(-90), LEAP_DURATION * 0.4)

	# Second half - slam down FAST
	tween.tween_property(self, "global_position", end_pos, LEAP_DURATION * 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Axe swings down during descent
	tween.parallel().tween_property(axe_visual, "rotation", deg_to_rad(110), LEAP_DURATION * 0.3)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	# Move player with us (smooth arc)
	if player_ref:
		var player_tween = TweenHelper.new_tween()
		player_tween.tween_property(player_ref, "global_position", mid_pos, LEAP_DURATION * 0.4)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		player_tween.tween_property(player_ref, "global_position", end_pos, LEAP_DURATION * 0.3)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# On impact
	tween.tween_callback(_on_impact)

	# Hold briefly with axe embedded
	tween.tween_interval(0.25)

	# Pull axe out animation
	tween.tween_property(axe_visual, "rotation", deg_to_rad(45), 0.15)
	tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.1)

	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.2)

	# Re-enable player vulnerability and cleanup
	tween.tween_callback(_cleanup)

func _on_impact():
	# Enable hitbox for damage
	$HitBox/CollisionShape2D.disabled = false

	# BIG screen shake
	DamageNumberManager.shake(0.7)

	# Impact visual - massive ground destruction
	_create_impact_effect()

	# Blood splatter if enemies hit
	_create_execution_effect()

	# Disable hitbox after brief moment
	await get_tree().create_timer(0.15).timeout
	if not is_instance_valid(self):
		return
	$HitBox/CollisionShape2D.disabled = true

func _create_impact_effect():
	# Multiple shockwaves for massive impact
	for i in range(3):
		_create_shockwave(i * 0.05, 1.0 - i * 0.25)

	# Deep ground cracks - more dramatic
	for i in range(12):
		var crack = ColorRect.new()
		crack.size = Vector2(IMPACT_RADIUS * randf_range(0.8, 1.4), randf_range(4, 8))
		crack.color = Color(0.25, 0.15, 0.1, 0.9)
		crack.pivot_offset = Vector2(0, crack.size.y / 2)
		crack.rotation = (TAU / 12) * i + randf_range(-0.15, 0.15)
		get_tree().current_scene.add_child(crack)
		crack.global_position = global_position
		crack.scale = Vector2(0, 1)

		var crack_tween = TweenHelper.new_tween()
		# Cracks shoot out
		crack_tween.tween_property(crack, "scale:x", 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		crack_tween.tween_interval(0.4)
		crack_tween.tween_property(crack, "modulate:a", 0.0, 0.5)
		crack_tween.tween_callback(crack.queue_free)

	# Rock debris flying up
	for i in range(16):
		var debris = ColorRect.new()
		var size = randf_range(10, 24)
		debris.size = Vector2(size, size)
		debris.color = Color(0.45, 0.35, 0.25, 1.0)
		debris.pivot_offset = debris.size / 2
		get_tree().current_scene.add_child(debris)
		debris.global_position = global_position + Vector2(randf_range(-25, 25), randf_range(-15, 15))

		var angle = randf_range(-PI * 0.85, -PI * 0.15)  # Upward arc
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(100, 200)
		var end_pos = debris.global_position + dir * dist

		var debris_tween = TweenHelper.new_tween()
		debris_tween.set_parallel(true)
		debris_tween.tween_property(debris, "global_position", end_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		debris_tween.tween_property(debris, "global_position:y", end_pos.y + 120, 0.6).set_delay(0.25)
		debris_tween.tween_property(debris, "rotation", randf_range(-TAU, TAU), 0.6)
		debris_tween.tween_property(debris, "modulate:a", 0.0, 0.6)
		debris_tween.tween_callback(debris.queue_free)

	# Metal sparks from axe impact
	for i in range(10):
		var spark = ColorRect.new()
		spark.size = Vector2(4, 10)
		spark.color = SPARK_COLOR
		spark.pivot_offset = Vector2(2, 5)
		get_tree().current_scene.add_child(spark)
		spark.global_position = global_position

		var angle = randf() * TAU
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(50, 120)

		var spark_tween = TweenHelper.new_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "global_position", global_position + dir * dist, 0.2)
		spark_tween.tween_property(spark, "scale", Vector2(0.2, 0.2), 0.2)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.2)
		spark_tween.tween_callback(spark.queue_free)

func _create_shockwave(delay: float, alpha: float):
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self):
		return

	var shockwave = ColorRect.new()
	shockwave.size = Vector2(50, 50)
	shockwave.color = Color(AXE_GLOW_COLOR.r, AXE_GLOW_COLOR.g, AXE_GLOW_COLOR.b, alpha)
	shockwave.pivot_offset = Vector2(25, 25)
	get_tree().current_scene.add_child(shockwave)
	shockwave.global_position = global_position - Vector2(25, 25)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(shockwave, "scale", Vector2(6, 6), 0.4)
	tween.tween_property(shockwave, "modulate:a", 0.0, 0.4)
	tween.tween_callback(shockwave.queue_free)

# ============================================
# VISUAL EFFECT HELPERS
# ============================================
func _create_leap_trail(start: Vector2, end: Vector2):
	# Ghost images along the leap path
	for i in range(5):
		var t = i / 5.0
		var pos = start.lerp(end, t)

		var ghost = ColorRect.new()
		ghost.size = Vector2(30, 50)
		ghost.color = Color(AXE_GLOW_COLOR.r, AXE_GLOW_COLOR.g, AXE_GLOW_COLOR.b, 0.0)
		ghost.pivot_offset = Vector2(15, 25)
		get_tree().current_scene.add_child(ghost)
		ghost.global_position = pos - Vector2(15, 25)

		# Fade in then out with delay
		var ghost_tween = TweenHelper.new_tween()
		ghost_tween.tween_property(ghost, "modulate:a", 0.4, 0.05).set_delay(i * 0.06)
		ghost_tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
		ghost_tween.tween_callback(ghost.queue_free)

func _create_windup_effect():
	# Particles gathering to axe before leap
	for i in range(6):
		var particle = ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.color = AXE_GLOW_COLOR
		particle.pivot_offset = Vector2(4, 4)
		get_tree().current_scene.add_child(particle)

		var angle = (TAU / 6) * i
		var start_pos = global_position + Vector2.from_angle(angle) * 60
		particle.global_position = start_pos

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", global_position, 0.15)
		tween.tween_property(particle, "scale", Vector2(0.3, 0.3), 0.15)
		tween.tween_callback(particle.queue_free)

func _create_execution_effect():
	# Dramatic blood/damage indicator effect
	for i in range(8):
		var blood = ColorRect.new()
		blood.size = Vector2(8, 16)
		blood.color = BLOOD_COLOR
		blood.pivot_offset = Vector2(4, 8)
		get_tree().current_scene.add_child(blood)
		blood.global_position = global_position

		var angle = randf() * TAU
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(60, 140)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(blood, "global_position", global_position + dir * dist, 0.35)
		tween.tween_property(blood, "scale:y", 2.0, 0.2)
		tween.tween_property(blood, "modulate:a", 0.0, 0.35)
		tween.tween_callback(blood.queue_free)

func _cleanup():
	# Re-enable player vulnerability
	if player_ref and player_ref.has_method("set_invulnerable"):
		player_ref.set_invulnerable(false)

	queue_free()

func _on_hit_box_area_entered(area: Area2D):
	var parent = area.get_parent()

	if parent in hits_this_slam:
		return

	if parent.has_method("take_damage"):
		hits_this_slam.append(parent)
		parent.take_damage(damage, global_position, 600.0, 0.3, player_ref)
		dealt_damage.emit(parent, damage)

func _on_hit_box_body_entered(body: Node2D):
	if body in hits_this_slam:
		return

	if body.has_method("take_damage"):
		hits_this_slam.append(body)
		body.take_damage(damage, global_position, 600.0, 0.3, player_ref)
		dealt_damage.emit(body, damage)
