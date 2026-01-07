# SCRIPT: BasicSwordSkill.gd
# ATTACH TO: BasicSwordSkill (Node2D) root node in BasicSwordSkill.tscn
# LOCATION: res://Scenes/Weapons/BasicSword/BasicSwordSkill.gd
# Giant Arc Slash - Single massive sweeping slash with sword sprite

extends Node2D

@onready var hit_box: Area2D = $HitBox
@onready var visual: Node2D = $Visual
@onready var sword_sprite: Sprite2D = $Visual/SwordSprite

@export var damage: float = 30.0
@export var arc_range: float = 350.0  # How far the arc extends
@export var arc_angle: float = 140.0  # Total sweep angle (degrees)
@export var knockback_force: float = 500.0
@export var knockback_stun: float = 0.2

var hits_this_slash: Array = []
var owner_ref: Node2D = null
var weapon_ref: WeakRef = null  # Reference to hide/show the weapon
var slash_direction: Vector2 = Vector2.RIGHT
var slash_center: Vector2 = Vector2.ZERO
var is_active: bool = true

# Visual colors - Epic blue-white energy
const SLASH_COLOR: Color = Color(0.7, 0.85, 1.0, 0.95)
const SLASH_GLOW: Color = Color(0.4, 0.6, 1.0, 0.6)
const SLASH_CORE: Color = Color(1.0, 1.0, 1.0, 1.0)

# Animation
const SWEEP_DURATION: float = 0.25

# Trail for single giant slash
var slash_trail: Line2D = null
var trail_points: Array[Vector2] = []

signal dealt_damage(target: Node2D, damage: float)

func _ready():
	if hit_box:
		hit_box.area_entered.connect(_on_hit_box_area_entered)
		hit_box.body_entered.connect(_on_hit_box_body_entered)
		hit_box.collision_mask = 28  # enemies (16) + portal (4) + walls (8)
		hit_box.monitoring = false  # Start disabled

func initialize(start_pos: Vector2, direction: Vector2, slash_damage: float, weapon_owner: Node2D = null, weapon: Node2D = null):
	slash_center = start_pos
	global_position = start_pos
	slash_direction = direction.normalized() if direction.length() > 0 else Vector2.RIGHT
	damage = slash_damage
	owner_ref = weapon_owner

	# Store weapon reference to hide/show it
	if weapon:
		weapon_ref = weakref(weapon)
		weapon.visible = false  # Hide weapon during skill

	_execute_arc_slash()

func _execute_arc_slash():
	var scene = get_tree().current_scene
	if not scene:
		_cleanup_and_free()
		return

	# Calculate arc start and end angles
	var center_angle = slash_direction.angle()
	var half_arc = deg_to_rad(arc_angle / 2.0)
	var start_angle = center_angle - half_arc
	var end_angle = center_angle + half_arc

	# Enable hitbox
	if hit_box:
		hit_box.monitoring = true

	# Create the single giant slash trail
	_create_slash_trail(scene)

	# Setup and animate the sword sprite
	_animate_sword_sweep(start_angle, end_angle)

	# Screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.4)

	# Sweep the hitbox across the arc
	await _sweep_hitbox(start_angle, end_angle)

	# Disable hitbox
	is_active = false
	if hit_box:
		hit_box.monitoring = false

	# Fade out the trail
	if slash_trail and is_instance_valid(slash_trail):
		var fade_tween = TweenHelper.new_tween()
		fade_tween.tween_property(slash_trail, "modulate:a", 0.0, 0.2)
		fade_tween.tween_callback(slash_trail.queue_free)

	# Fade out and cleanup
	var fade_tween = TweenHelper.new_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	fade_tween.tween_callback(_cleanup_and_free)

func _cleanup_and_free():
	# Show weapon again before freeing
	if weapon_ref:
		var weapon = weapon_ref.get_ref()
		if weapon and is_instance_valid(weapon):
			weapon.visible = true
	queue_free()

func _create_slash_trail(scene: Node):
	# Create a single Line2D for the giant slash arc
	slash_trail = Line2D.new()
	slash_trail.width = 60.0  # Thick slash
	slash_trail.default_color = SLASH_COLOR
	slash_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	slash_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	slash_trail.z_index = 5

	# Width curve - thick in middle, tapered at ends
	var width_curve = Curve.new()
	width_curve.add_point(Vector2(0.0, 0.3))  # Start thin
	width_curve.add_point(Vector2(0.3, 0.9))
	width_curve.add_point(Vector2(0.5, 1.0))  # Middle thick
	width_curve.add_point(Vector2(0.7, 0.9))
	width_curve.add_point(Vector2(1.0, 0.3))  # End thin
	slash_trail.width_curve = width_curve

	# Gradient - white core to blue edge
	var gradient = Gradient.new()
	gradient.set_color(0, SLASH_CORE)
	gradient.set_color(1, SLASH_GLOW)
	slash_trail.gradient = gradient

	scene.add_child(slash_trail)
	trail_points.clear()

func _animate_sword_sweep(start_angle: float, end_angle: float):
	if not sword_sprite or not visual:
		return

	# Position sword at arc edge
	sword_sprite.position = Vector2(arc_range * 0.6, 0)

	# Start rotation
	visual.rotation = start_angle

	# Scale up sword for dramatic effect
	sword_sprite.scale = Vector2(2.5, 2.5)
	sword_sprite.modulate = Color(1.3, 1.3, 1.5, 1.0)  # Bright glow

	# Animate the sword sweeping across the arc
	var tween = TweenHelper.new_tween()

	# Fast powerful sweep
	tween.tween_property(visual, "rotation", end_angle, SWEEP_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Sword spins slightly during sweep
	tween.parallel().tween_property(sword_sprite, "rotation", deg_to_rad(180), SWEEP_DURATION)

func _sweep_hitbox(start_angle: float, end_angle: float):
	var sweep_time = SWEEP_DURATION
	var elapsed = 0.0
	var delta_time = 0.012  # Faster updates for smoother trail

	while elapsed < sweep_time:
		if not is_instance_valid(self):
			return

		var progress = elapsed / sweep_time
		var current_angle = lerp(start_angle, end_angle, progress)

		# Position hitbox at current sweep position
		var hitbox_pos = slash_center + Vector2.from_angle(current_angle) * (arc_range * 0.6)
		hit_box.global_position = hitbox_pos

		# Add point to trail
		var trail_pos = slash_center + Vector2.from_angle(current_angle) * arc_range
		trail_points.append(trail_pos)
		if slash_trail and is_instance_valid(slash_trail):
			slash_trail.add_point(trail_pos)

		# Check enemies in the arc
		_check_enemies_in_arc()

		await get_tree().create_timer(delta_time).timeout
		elapsed += delta_time

func _check_enemies_in_arc():
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy in hits_this_slash:
			continue
		if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
			continue

		var to_enemy = enemy.global_position - slash_center
		var distance = to_enemy.length()

		# Check if within range
		if distance > arc_range + 50:
			continue

		# Check if within arc angle
		var enemy_angle = to_enemy.angle()
		var center_angle = slash_direction.angle()
		var angle_diff = abs(wrapf(enemy_angle - center_angle, -PI, PI))

		if angle_diff <= deg_to_rad(arc_angle / 2.0) + 0.1:
			_hit_enemy(enemy)

func _hit_enemy(enemy: Node2D):
	if enemy in hits_this_slash:
		return

	hits_this_slash.append(enemy)

	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, slash_center, knockback_force, knockback_stun, owner_ref)
		dealt_damage.emit(enemy, damage)
		_create_hit_effect(enemy.global_position)

func _on_hit_box_area_entered(area: Area2D):
	var target = area if area.has_method("take_damage") else area.get_parent()

	if target in hits_this_slash:
		return

	if target.is_in_group("converted_minion") or target.is_in_group("player_minions"):
		return

	_hit_enemy(target)

func _on_hit_box_body_entered(body: Node2D):
	if body in hits_this_slash:
		return

	if body.has_method("take_damage"):
		_hit_enemy(body)

func _create_hit_effect(hit_pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Impact flash
	var flash = ColorRect.new()
	flash.size = Vector2(60, 60)
	flash.color = SLASH_CORE
	flash.pivot_offset = Vector2(30, 30)
	scene.add_child(flash)
	flash.global_position = hit_pos - Vector2(30, 30)
	flash.z_index = 10

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.1)
	tween.tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.tween_callback(flash.queue_free)

	# Screen shake per hit
	if DamageNumberManager:
		DamageNumberManager.shake(0.15)
