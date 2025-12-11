# SCRIPT: FireGrateHazard.gd
# ATTACH TO: FireGrate (Area2D) - Damage over time zone hazard
# LOCATION: res://Scripts/hazards/FireGrateHazard.gd

class_name FireGrateHazard
extends Hazard

# ============================================
# FIRE SETTINGS
# ============================================
@export_group("Fire Settings")
@export var damage_per_second: float = 15.0
@export var damage_tick_rate: float = 0.25  # Damage every 0.25 seconds

# ============================================
# NODE REFERENCES
# ============================================
@onready var grate_sprite: ColorRect = $GrateSprite if has_node("GrateSprite") else null
@onready var fire_particles: Node2D = $FireParticles if has_node("FireParticles") else null
@onready var glow_light: PointLight2D = $GlowLight if has_node("GlowLight") else null

# ============================================
# STATE
# ============================================
var damage_timer: float = 0.0
var bodies_on_grate: Array[Node2D] = []
var fire_flicker_timer: float = 0.0

# ============================================
# SETUP
# ============================================
func _setup_hazard() -> void:
	hazard_type = HazardType.ZONE
	activation_type = ActivationType.ALWAYS_ACTIVE
	is_instant_kill = false

	# Calculate tick damage
	damage = damage_per_second * damage_tick_rate

# ============================================
# PROCESS
# ============================================
func _process(delta: float) -> void:
	if not is_active:
		return

	# Update fire visual effects
	_update_fire_visuals(delta)

	# Damage tick timer
	damage_timer += delta
	if damage_timer >= damage_tick_rate:
		damage_timer = 0.0
		_apply_damage_tick()

func _update_fire_visuals(delta: float) -> void:
	fire_flicker_timer += delta

	# Flicker the fire particles (simulate randomness)
	if fire_particles:
		var flicker = 0.8 + sin(fire_flicker_timer * 15.0) * 0.2
		fire_particles.modulate.a = flicker

	# Flicker the glow light
	if glow_light:
		var light_flicker = 0.7 + sin(fire_flicker_timer * 12.0) * 0.3
		glow_light.energy = light_flicker

	# Slight color variation on the grate
	if grate_sprite and active_sprite:
		var heat_pulse = 0.9 + sin(fire_flicker_timer * 8.0) * 0.1
		# Subtle red-orange pulse
		active_sprite.modulate = Color(1.0, heat_pulse, heat_pulse * 0.8, 1.0)

# ============================================
# BODY CONTACT HANDLING
# ============================================
func _on_body_entered(body: Node2D) -> void:
	if not can_affect(body):
		return

	if body not in bodies_in_hazard:
		bodies_in_hazard.append(body)

	if body not in bodies_on_grate:
		bodies_on_grate.append(body)

	# Immediate first tick of damage when entering
	if is_active:
		apply_tick_damage(body)

func _on_body_exited(body: Node2D) -> void:
	bodies_in_hazard.erase(body)
	bodies_on_grate.erase(body)

func _handle_body_contact(body: Node2D) -> void:
	# DoT is handled in _process, but add to tracking
	if body not in bodies_on_grate:
		bodies_on_grate.append(body)
		apply_tick_damage(body)

# ============================================
# DAMAGE SYSTEM
# ============================================
func _apply_damage_tick() -> void:
	# Clean up invalid bodies
	var valid_bodies: Array[Node2D] = []
	for body in bodies_on_grate:
		if is_instance_valid(body):
			valid_bodies.append(body)
	bodies_on_grate = valid_bodies

	# Apply damage to all bodies on grate
	for body in bodies_on_grate:
		apply_tick_damage(body)

func apply_tick_damage(body: Node2D) -> void:
	if not is_instance_valid(body):
		return

	var tick_damage = damage_per_second * damage_tick_rate

	if body.has_method("take_damage"):
		if body.is_in_group("player"):
			body.take_damage(tick_damage, global_position)
		else:
			# No knockback for fire damage
			body.take_damage(tick_damage, Vector2.ZERO, 0.0, 0.0)

		body_damaged.emit(body, tick_damage)

		# Show damage number (less frequently to avoid spam)
		if randf() < 0.5:  # 50% chance to show number
			_spawn_fire_damage_number(body, tick_damage)

		# Play sizzle effect on body
		_play_sizzle_effect(body)

func _spawn_fire_damage_number(body: Node2D, damage_amount: float) -> void:
	var damage_number = DamageNumber.instantiate()
	damage_number.global_position = body.global_position + Vector2(randf_range(-10, 10), -20)
	get_tree().current_scene.add_child(damage_number)
	damage_number.setup(damage_amount)

	# Tint the damage number orange for fire damage
	damage_number.modulate = Color(1, 0.6, 0.2, 1)

func _play_sizzle_effect(body: Node2D) -> void:
	# Brief orange flash on the body
	var visual_node = _get_visual_node(body)
	if visual_node and is_instance_valid(visual_node):
		# Only flash if not already being modified
		var original_modulate = visual_node.modulate
		visual_node.modulate = Color(1, 0.7, 0.4, original_modulate.a)

		# Quick return to normal
		var tween = create_tween()
		tween.tween_property(visual_node, "modulate", original_modulate, 0.15)

func _get_visual_node(body: Node2D) -> Node2D:
	if body.has_node("VisualsPivot"):
		return body.get_node("VisualsPivot")
	if body.has_node("Sprite2D"):
		return body.get_node("Sprite2D")
	return body

# ============================================
# UTILITY
# ============================================
func get_bodies_count() -> int:
	return bodies_on_grate.size()

func is_body_on_fire(body: Node2D) -> bool:
	return body in bodies_on_grate
