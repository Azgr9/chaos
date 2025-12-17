# SCRIPT: GuillotineDrop.gd
# ATTACH TO: GuillotineDrop (Node2D) root node in GuillotineDrop.tscn
# LOCATION: res://Scripts/Weapons/GuillotineDrop.gd
# Executioner's Axe skill - leap forward, deal 3x damage in small AoE

extends Node2D

@onready var hit_box: Area2D = $HitBox
@onready var visual: Node2D = $Visual
@onready var axe_visual: ColorRect = $Visual/Axe

const LEAP_DISTANCE: float = 200.0  # How far to leap
const LEAP_DURATION: float = 0.35
const IMPACT_RADIUS: float = 80.0

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

	# Initial state - axe raised
	visual.scale = Vector2(1.2, 1.2)
	modulate.a = 1.0
	axe_visual.rotation = deg_to_rad(-45)  # Raised

	var tween = create_tween()

	# Move to target while raising axe higher
	tween.tween_property(self, "global_position", end_pos, LEAP_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Simultaneously rotate axe down
	tween.parallel().tween_property(axe_visual, "rotation", deg_to_rad(90), LEAP_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Move player with us
	if player_ref:
		tween.parallel().tween_property(player_ref, "global_position", end_pos, LEAP_DURATION)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# On impact
	tween.tween_callback(_on_impact)

	# Hold briefly
	tween.tween_interval(0.2)

	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.3)

	# Re-enable player vulnerability and cleanup
	tween.tween_callback(_cleanup)

func _on_impact():
	# Enable hitbox for damage
	$HitBox/CollisionShape2D.disabled = false

	# Screen shake
	DamageNumberManager.shake(0.5)

	# Impact visual - ground crack
	_create_impact_effect()

	# Disable hitbox after brief moment
	await get_tree().create_timer(0.1).timeout
	$HitBox/CollisionShape2D.disabled = true

func _create_impact_effect():
	# Shockwave
	var shockwave = ColorRect.new()
	shockwave.size = Vector2(40, 40)
	shockwave.color = Color(0.8, 0.3, 0.1, 0.9)
	shockwave.pivot_offset = Vector2(20, 20)
	get_tree().current_scene.add_child(shockwave)
	shockwave.global_position = global_position - Vector2(20, 20)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(shockwave, "scale", Vector2(5, 5), 0.4)
	tween.tween_property(shockwave, "modulate:a", 0.0, 0.4)
	tween.tween_callback(shockwave.queue_free)

	# Ground cracks - 8 lines radiating out
	for i in range(8):
		var crack = ColorRect.new()
		crack.size = Vector2(IMPACT_RADIUS, 6)
		crack.color = Color(0.4, 0.2, 0.1, 0.8)
		crack.pivot_offset = Vector2(0, 3)
		crack.rotation = (TAU / 8) * i
		get_tree().current_scene.add_child(crack)
		crack.global_position = global_position

		var crack_tween = create_tween()
		crack_tween.set_parallel(true)
		crack_tween.tween_property(crack, "scale:x", 0.0, 0.5).set_delay(0.2)
		crack_tween.tween_property(crack, "modulate:a", 0.0, 0.5).set_delay(0.2)
		crack_tween.tween_callback(crack.queue_free)

	# Dust particles
	for i in range(12):
		var dust = ColorRect.new()
		dust.size = Vector2(16, 16)
		dust.color = Color(0.6, 0.5, 0.4, 0.8)
		get_tree().current_scene.add_child(dust)
		dust.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))

		var angle = (TAU / 12) * i + randf_range(-0.3, 0.3)
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(60, 120)

		var dust_tween = create_tween()
		dust_tween.set_parallel(true)
		dust_tween.tween_property(dust, "global_position", dust.global_position + dir * dist, 0.4)
		dust_tween.tween_property(dust, "global_position:y", dust.global_position.y - 40, 0.2)
		dust_tween.tween_property(dust, "modulate:a", 0.0, 0.4)
		dust_tween.tween_callback(dust.queue_free)

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
