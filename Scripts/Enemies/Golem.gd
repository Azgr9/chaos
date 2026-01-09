# SCRIPT: Golem.gd
# ATTACH TO: Golem (CharacterBody2D) root node in Golem.tscn
# LOCATION: res://Scripts/Enemies/Golem.gd
# Tank enemy - slow but high HP and damage, has ground slam attack

class_name Golem
extends Enemy

# ============================================
# GOLEM-SPECIFIC SETTINGS
# ============================================
@export var slam_damage: float = 25.0
@export var slam_radius: float = 120.0
@export var slam_cooldown: float = 4.0
@export var charge_speed: float = 400.0
@export var unlocks_at_wave: int = 5

# Animation constants
const IDLE_BOB_SPEED: float = 2.0
const IDLE_BOB_RANGE: float = 4.0
const STEP_INTERVAL: float = 0.4

# ============================================
# NODES
# ============================================
@onready var visuals_pivot: Node2D = $VisualsPivot
@onready var body_sprite: ColorRect = $VisualsPivot/Body
@onready var head_sprite: ColorRect = $VisualsPivot/Head
@onready var left_arm: ColorRect = $VisualsPivot/LeftArm
@onready var right_arm: ColorRect = $VisualsPivot/RightArm
@onready var attack_box: Area2D = $AttackBox

# ============================================
# STATE
# ============================================
var slam_timer: float = 0.0
var is_slamming: bool = false
var is_charging: bool = false
var time_alive: float = 0.0
var step_timer: float = 0.0

# ============================================
# COLORS
# ============================================
const GOLEM_BODY_COLOR = Color(0.4, 0.35, 0.3)  # Stone gray-brown
const GOLEM_HEAD_COLOR = Color(0.5, 0.45, 0.4)  # Lighter stone
const GOLEM_ARM_COLOR = Color(0.35, 0.3, 0.25)   # Darker stone
const GOLEM_EYE_COLOR = Color(1.0, 0.3, 0.1)     # Glowing orange eyes

func _setup_enemy():
	current_health = max_health
	slam_timer = slam_cooldown * 0.5  # Start with partial cooldown

	# Connect attack box
	attack_box.area_entered.connect(_on_attack_box_area_entered)

	# Setup visual appearance
	_setup_visuals()

func _setup_visuals():
	# Body - large rectangular torso
	body_sprite.color = GOLEM_BODY_COLOR
	body_sprite.size = Vector2(60, 80)
	body_sprite.position = Vector2(-30, -80)

	# Head - smaller square
	head_sprite.color = GOLEM_HEAD_COLOR
	head_sprite.size = Vector2(40, 40)
	head_sprite.position = Vector2(-20, -130)

	# Arms - thick rectangles
	left_arm.color = GOLEM_ARM_COLOR
	left_arm.size = Vector2(25, 60)
	left_arm.position = Vector2(-55, -70)

	right_arm.color = GOLEM_ARM_COLOR
	right_arm.size = Vector2(25, 60)
	right_arm.position = Vector2(30, -70)

	# Add eyes (glowing)
	_create_eyes()

func _create_eyes():
	# Left eye
	var left_eye = ColorRect.new()
	left_eye.color = GOLEM_EYE_COLOR
	left_eye.size = Vector2(8, 8)
	left_eye.position = Vector2(-15, -120)
	visuals_pivot.add_child(left_eye)

	# Right eye
	var right_eye = ColorRect.new()
	right_eye.color = GOLEM_EYE_COLOR
	right_eye.size = Vector2(8, 8)
	right_eye.position = Vector2(7, -120)
	visuals_pivot.add_child(right_eye)

func _physics_process(delta):
	if is_dead:
		return

	time_alive += delta
	slam_timer -= delta
	step_timer += delta

	# Idle animation - slow bob
	if not is_slamming and not is_charging:
		var bob = sin(time_alive * IDLE_BOB_SPEED) * IDLE_BOB_RANGE
		visuals_pivot.position.y = bob

		# Arm swing while walking
		if velocity.length() > 10:
			var arm_swing = sin(time_alive * 8) * 10
			left_arm.rotation = deg_to_rad(arm_swing)
			right_arm.rotation = deg_to_rad(-arm_swing)

	super._physics_process(delta)

func _update_movement(_delta):
	if knockback_velocity.length() > 0 or is_slamming:
		return

	var target = get_best_target()
	if not target:
		velocity = Vector2.ZERO
		return

	var direction_to_target = (target.global_position - global_position).normalized()
	var distance_to_target = global_position.distance_to(target.global_position)

	# Update facing
	if direction_to_target.x < 0:
		visuals_pivot.scale.x = -1
	else:
		visuals_pivot.scale.x = 1

	# Check for slam attack
	if distance_to_target < slam_radius * 1.5 and slam_timer <= 0:
		_perform_slam()
		return

	# Move toward target (slower than other enemies)
	velocity = direction_to_target * move_speed

	# Step sound/effect
	if step_timer >= STEP_INTERVAL and velocity.length() > 10:
		step_timer = 0.0
		_create_step_effect()

func _perform_slam():
	is_slamming = true
	slam_timer = slam_cooldown
	velocity = Vector2.ZERO

	# Wind up animation - raise arms
	var tween = TweenHelper.new_tween()
	tween.tween_property(left_arm, "position:y", left_arm.position.y - 40, 0.3)
	tween.parallel().tween_property(right_arm, "position:y", right_arm.position.y - 40, 0.3)
	tween.parallel().tween_property(visuals_pivot, "position:y", -20, 0.3)

	# Slam down
	tween.tween_property(left_arm, "position:y", left_arm.position.y + 20, 0.1)
	tween.parallel().tween_property(right_arm, "position:y", right_arm.position.y + 20, 0.1)
	tween.parallel().tween_property(visuals_pivot, "position:y", 10, 0.1)

	tween.tween_callback(_execute_slam)

	# Return to normal
	tween.tween_property(left_arm, "position:y", left_arm.position.y, 0.3)
	tween.parallel().tween_property(right_arm, "position:y", right_arm.position.y, 0.3)
	tween.parallel().tween_property(visuals_pivot, "position:y", 0, 0.3)

	tween.tween_callback(func(): is_slamming = false)

func _execute_slam():
	# Screen shake
	DamageNumberManager.shake(0.6)

	# Create ground crack effect
	_create_slam_effect()

	# Damage all nearby targets
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= slam_radius:
			if player.has_method("take_damage"):
				player.take_damage(slam_damage, global_position)

func _create_slam_effect():
	var scene = get_tree().current_scene
	if not scene:
		return

	# Expanding shockwave ring
	var ring = ColorRect.new()
	ring.size = Vector2(40, 40)
	ring.pivot_offset = Vector2(20, 20)
	ring.color = Color(0.6, 0.5, 0.4, 0.8)
	scene.add_child(ring)
	ring.global_position = global_position - Vector2(20, 20)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(8, 8), 0.3)
	tween.tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ring.queue_free)

	# Debris particles
	for i in range(8):
		var debris = ColorRect.new()
		debris.size = Vector2(12, 12)
		debris.color = GOLEM_BODY_COLOR
		scene.add_child(debris)
		debris.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))

		var angle = randf() * TAU
		var end_pos = debris.global_position + Vector2.from_angle(angle) * randf_range(60, 100)

		var d_tween = TweenHelper.new_tween()
		d_tween.set_parallel(true)
		d_tween.tween_property(debris, "global_position", end_pos, 0.4)
		d_tween.tween_property(debris, "global_position:y", end_pos.y + 50, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		d_tween.tween_property(debris, "modulate:a", 0.0, 0.4)
		d_tween.tween_callback(debris.queue_free)

func _create_step_effect():
	var scene = get_tree().current_scene
	if not scene:
		return

	# Small dust puff
	var dust = ColorRect.new()
	dust.size = Vector2(20, 10)
	dust.pivot_offset = Vector2(10, 5)
	dust.color = Color(0.5, 0.45, 0.4, 0.5)
	scene.add_child(dust)
	dust.global_position = global_position + Vector2(-10, 5)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(dust, "scale", Vector2(2, 2), 0.2)
	tween.tween_property(dust, "modulate:a", 0.0, 0.2)
	tween.tween_callback(dust.queue_free)

func _on_damage_taken():
	super._on_damage_taken()

	# Golem is heavy - less knockback reaction
	knockback_velocity *= 0.3

func _play_hit_squash():
	# Minimal squash for heavy golem
	visuals_pivot.scale.y = 0.95
	var tween = TweenHelper.new_tween()
	tween.tween_property(visuals_pivot, "scale:y", 1.0, 0.1)

func _on_death():
	set_physics_process(false)

	# Crumble apart animation
	var tween = TweenHelper.new_tween()

	# Head falls off
	tween.tween_property(head_sprite, "position:y", head_sprite.position.y + 150, 0.4)
	tween.parallel().tween_property(head_sprite, "rotation", randf_range(-0.5, 0.5), 0.4)

	# Arms fall
	tween.parallel().tween_property(left_arm, "position:y", left_arm.position.y + 130, 0.5)
	tween.parallel().tween_property(left_arm, "rotation", deg_to_rad(-45), 0.5)
	tween.parallel().tween_property(right_arm, "position:y", right_arm.position.y + 130, 0.5)
	tween.parallel().tween_property(right_arm, "rotation", deg_to_rad(45), 0.5)

	# Body crumbles
	tween.parallel().tween_property(body_sprite, "scale:y", 0.3, 0.5)
	tween.parallel().tween_property(visuals_pivot, "modulate:a", 0.0, 0.6)

	tween.tween_callback(queue_free)

func _get_death_particle_color() -> Color:
	return GOLEM_BODY_COLOR

func _get_death_particle_count() -> int:
	return 12  # More particles for bigger enemy

func _on_attack_box_area_entered(area: Area2D):
	if is_dead:
		return

	var parent = area.get_parent()
	if parent and parent.has_method("take_damage"):
		parent.take_damage(damage, global_position)
