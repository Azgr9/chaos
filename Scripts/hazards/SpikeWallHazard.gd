# SCRIPT: SpikeWallHazard.gd
# ATTACH TO: SpikeWall (Area2D) - Impact damage hazard
# LOCATION: res://Scripts/hazards/SpikeWallHazard.gd

class_name SpikeWallHazard
extends Hazard

# ============================================
# IMPACT SETTINGS
# ============================================
@export_group("Impact Settings")
@export var impact_damage: float = 40.0
@export var impact_velocity_threshold: float = 150.0  # Min speed to take damage
@export var knockback_away_power: float = 400.0

@export_group("Visual Settings")
@export var wall_orientation: float = 0.0  # Rotation in degrees (0, 90, 180, 270)

# ============================================
# STATE
# ============================================
var recent_impacts: Dictionary = {}  # body_id -> timestamp
const IMPACT_COOLDOWN: float = 0.5

# ============================================
# SETUP
# ============================================
func _setup_hazard() -> void:
	hazard_type = HazardType.IMPACT
	activation_type = ActivationType.ON_IMPACT
	damage = impact_damage
	is_instant_kill = false

	# Apply rotation
	rotation_degrees = wall_orientation

# ============================================
# PROCESS
# ============================================
func _process(_delta: float) -> void:
	# Clean up old impact records
	var current_time = Time.get_ticks_msec() / 1000.0
	var to_remove: Array = []

	for body_id in recent_impacts.keys():
		if current_time - recent_impacts[body_id] > IMPACT_COOLDOWN:
			to_remove.append(body_id)

	for body_id in to_remove:
		recent_impacts.erase(body_id)

# ============================================
# BODY CONTACT HANDLING
# ============================================
func _on_body_entered(body: Node2D) -> void:
	if not can_affect(body):
		return

	if body not in bodies_in_hazard:
		bodies_in_hazard.append(body)

	# Check for valid impact
	if is_active and is_valid_impact(body):
		apply_impact_damage(body)

func _handle_body_contact(body: Node2D) -> void:
	# Override - spike walls only damage on high-velocity impact
	if is_valid_impact(body):
		apply_impact_damage(body)

# ============================================
# IMPACT DETECTION
# ============================================
func is_valid_impact(body: Node2D) -> bool:
	# Check if on cooldown
	var body_id = body.get_instance_id()
	var current_time = Time.get_ticks_msec() / 1000.0

	if recent_impacts.has(body_id):
		if current_time - recent_impacts[body_id] < IMPACT_COOLDOWN:
			return false

	# Get body velocity
	var body_velocity = _get_body_velocity(body)
	if body_velocity == Vector2.ZERO:
		return false

	# Check velocity magnitude
	var speed = body_velocity.length()
	if speed < impact_velocity_threshold:
		return false

	# Check impact angle - body must be moving TOWARD the wall
	var wall_normal = _get_wall_normal()
	var velocity_direction = body_velocity.normalized()

	# Dot product: negative means moving toward wall
	var dot = velocity_direction.dot(wall_normal)
	if dot >= -0.3:  # Allow some angle tolerance
		return false

	return true

func _get_body_velocity(body: Node2D) -> Vector2:
	# Try to get velocity from CharacterBody2D
	if body is CharacterBody2D:
		return body.velocity

	# Try to get knockback velocity from enemies
	if "knockback_velocity" in body:
		return body.knockback_velocity

	# Fallback: no velocity detected
	return Vector2.ZERO

func _get_wall_normal() -> Vector2:
	# The wall faces "outward" (away from the spikes)
	# Default orientation: wall is horizontal, spikes point up (normal is up/negative Y)
	var base_normal = Vector2(0, -1)

	# Rotate normal based on wall orientation
	return base_normal.rotated(deg_to_rad(wall_orientation))

# ============================================
# DAMAGE APPLICATION
# ============================================
func apply_impact_damage(body: Node2D) -> void:
	if not is_instance_valid(body):
		return

	# Record this impact
	var body_id = body.get_instance_id()
	recent_impacts[body_id] = Time.get_ticks_msec() / 1000.0

	# Calculate knockback direction (away from wall)
	var knockback_dir = _get_wall_normal()

	# Apply damage with knockback
	if body.has_method("take_damage"):
		if body.is_in_group("player"):
			body.take_damage(impact_damage, global_position)
			# Apply additional knockback for player
			if body is CharacterBody2D:
				body.velocity = knockback_dir * knockback_away_power
		else:
			# Enemies get knockback through the damage function
			body.take_damage(impact_damage, global_position, knockback_away_power, 0.15, null)

	# Emit signal
	body_damaged.emit(body, impact_damage)

	# Visual feedback
	_play_impact_effect(body)

	# Screen shake
	add_screen_shake(0.3)

	print("[SpikeWall] Impact! Dealt %d damage to %s" % [int(impact_damage), body.name])

func _play_impact_effect(body: Node2D) -> void:
	# Flash the spikes red
	if active_sprite:
		var original_modulate = active_sprite.modulate
		active_sprite.modulate = Color(1, 0.3, 0.3, 1)

		var tween = create_tween()
		tween.tween_property(active_sprite, "modulate", original_modulate, 0.2)

	# Spawn impact particles (blood/sparks)
	_spawn_impact_particles(body.global_position)

func _spawn_impact_particles(impact_pos: Vector2) -> void:
	var particle_count = 5
	var particle_color = Color(0.8, 0.1, 0.1, 1)  # Blood red

	for i in range(particle_count):
		var particle = ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.color = particle_color
		particle.global_position = impact_pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		get_tree().current_scene.add_child(particle)

		var tween = create_tween()
		var fly_dir = _get_wall_normal() + Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
		tween.tween_property(particle, "global_position", particle.global_position + fly_dir * 60, 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_callback(particle.queue_free)
